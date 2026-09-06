# The release engine behind script/alpha_release, script/beta_release and script/publish_release:
# notarize, archive, sign for Sparkle, release on GitHub, and add the entry to the feed.
#
# The version comes from the newest heading in Changes.md. A prerelease gets a suffix whose number is
# one more than the tags that already carry that channel, so nothing is edited by hand between
# alphas. The build number is the commit count, which the build derives itself.
#
# What happens, in order: a prerelease.rave carrying the suffix is written for this one build,
# script/notarize builds, signs, submits and staples, the stapled application is zipped, the zip is
# signed with the production Sparkle key from the login keychain, a GitHub Release is created for
# the tag with the zip attached, and the entry is added to the appcast in the catalog repository
# next to this one and pushed, which is what the running application checks.
#
# Needs: main checked out and clean, the Developer ID identity in local.rave, the notarytool
# keychain profile, the Sparkle production key under the textmate3-production account, gh logged
# in, and the catalog repository checked out beside this one with push access.

require "fileutils"
require "shellwords"
require "rexml/document"
require "time"

class Release
  ROOT          = File.expand_path("../..", __dir__)
  CATALOG       = File.expand_path("../api.textmate3.com", ROOT)
  APPCAST       = File.join(CATALOG, "docs/appcast.xml")
  CHANGES       = File.join(ROOT, "Applications/TextMate/about/Changes.md")
  BUILD_DIR     = File.expand_path("~/build/textmate/release")
  APP           = File.join(BUILD_DIR, "Applications/TextMate/TextMate.app")
  RELEASES_DIR  = File.join(BUILD_DIR, "_Release")
  SIGN_UPDATE   = File.join(ROOT, "vendor/Sparkle/bin/sign_update")
  SPARKLE_KEY   = "textmate3-production"
  REPOSITORY    = "textmate3/textmate"
  MINIMUM_MACOS = "26.0"
  CHANNELS      = %w[alpha beta release].freeze

  attr_reader :channel, :base_version, :version, :tag

  def initialize(channel)
    abort "release: unknown channel #{channel}" unless CHANNELS.include?(channel)
    Dir.chdir(ROOT)
    @channel = channel
    @base_version = File.read(CHANGES)[/^## .* \(v(.+?)\)$/, 1] or abort "release: no version heading in Changes.md"
    @version = prerelease? ? "#{base_version}-#{channel}.#{existing_tags.map { |tag| tag[/\.(\d+)\z/, 1].to_i }.max.to_i + 1}" : base_version
    @tag = "v#{version}"
  end

  def prerelease?
    channel != "release"
  end

  def run
    check_preconditions
    puts "Releasing #{version} on the #{channel} channel"
    build
    zip = archive
    signature, length = sign(zip)
    notes_file = write_notes
    download_url = publish_on_github(zip, notes_file)
    publish_in_feed(download_url, signature, length, File.read(notes_file))

    puts
    puts "Released #{version}"
    puts "  archive  #{download_url}"
    puts "  feed     https://api.textmate3.com/appcast.xml"
    puts "  notes    #{notes_file}"
  end

  private

  def run!(*command)
    puts "→ #{command.map(&:to_s).shelljoin}"
    system(*command) or abort "release: #{command.first} failed"
  end

  def capture(*command)
    output = IO.popen(command, &:read)
    abort "release: #{command.first} failed" unless $?.success?
    output.strip
  end

  # Each precondition named, so the failure says what to fix.
  def check_preconditions
    abort "release: releases come from main, not #{capture("git", "branch", "--show-current")}" unless capture("git", "branch", "--show-current") == "main"
    abort "release: the tree has uncommitted changes" unless capture("git", "status", "--porcelain").empty?
    abort "release: no Developer ID identity in local.rave" unless File.exist?("local.rave") && File.read("local.rave") =~ /^set CS_IDENTITY\s+"Developer ID/
    abort "release: the catalog repository is not beside this one at #{CATALOG}" unless File.exist?(APPCAST)
    abort "release: #{tag} already exists" unless capture("git", "tag", "--list", tag).empty?
    run! "gh", "auth", "status"
  end

  def existing_tags
    capture("git", "tag", "--list", "v#{base_version}-#{channel}.*").lines.map(&:strip)
  end

  # The build, with the suffix in place for it and gone after.
  def build
    File.write("prerelease.rave", "set APP_PRERELEASE \"#{prerelease? ? version.sub(base_version, "") : ""}\"\n")
    begin
      run! "script/notarize"
    ensure
      FileUtils.rm_f("prerelease.rave")
    end

    built = capture("plutil", "-extract", "CFBundleShortVersionString", "raw", "-o", "-", File.join(APP, "Contents/Info.plist"))
    abort "release: the built application says #{built}, not #{version}" unless built == version
  end

  def build_number
    capture("plutil", "-extract", "CFBundleVersion", "raw", "-o", "-", File.join(APP, "Contents/Info.plist"))
  end

  def archive
    FileUtils.mkdir_p(RELEASES_DIR)
    zip = File.join(RELEASES_DIR, "TextMate-#{version}.zip")
    FileUtils.rm_f(zip)
    run! "/usr/bin/ditto", "-c", "-k", "--keepParent", APP, zip
    zip
  end

  def sign(zip)
    attributes = capture(SIGN_UPDATE, "--account", SPARKLE_KEY, zip)
    signature = attributes[/sparkle:edSignature="([^"]+)"/, 1]
    length    = attributes[/length="(\d+)"/, 1]
    abort "release: sign_update gave no signature" unless signature && length
    [signature, length]
  end

  # What landed since the previous tag on this channel, or since the last tag of any kind.
  def write_notes
    previous = existing_tags.max_by { |tag| tag[/\.(\d+)\z/, 1].to_i } || capture("git", "describe", "--tags", "--abbrev=0", "--always", "HEAD~1")
    notes = capture("git", "log", "--format=- %s", "#{previous}..HEAD")
    notes = "- The first #{channel} of #{base_version}." if notes.empty?
    notes_file = File.join(RELEASES_DIR, "TextMate-#{version}.md")
    File.write(notes_file, notes + "\n")
    notes_file
  end

  def publish_on_github(zip, notes_file)
    arguments = ["gh", "release", "create", tag, zip, "--repo", REPOSITORY, "--title", "TextMate #{version}", "--notes-file", notes_file, "--target", capture("git", "rev-parse", "HEAD")]
    arguments << "--prerelease" if prerelease?
    run!(*arguments)
    "https://github.com/#{REPOSITORY}/releases/download/#{tag}/#{File.basename(zip)}"
  end

  # The appcast entry, newest first, in the channel's name for a prerelease.
  def publish_in_feed(download_url, signature, length, notes)
    document = REXML::Document.new(File.read(APPCAST))
    feed     = document.elements["rss/channel"] or abort "release: #{APPCAST} has no channel"

    item = REXML::Element.new("item")
    item.add_element("title").text = "TextMate #{version}"
    item.add_element("sparkle:version").text = build_number
    item.add_element("sparkle:shortVersionString").text = version
    item.add_element("sparkle:channel").text = channel if prerelease?
    item.add_element("sparkle:minimumSystemVersion").text = MINIMUM_MACOS
    item.add_element("pubDate").text = Time.now.utc.rfc2822
    item.add_element("link").text = "https://github.com/#{REPOSITORY}/releases/tag/#{tag}"
    description = item.add_element("description")
    description.add(REXML::CData.new("<ul>\n" + notes.lines.map { |line| "<li>#{line.sub(/^- /, "").strip}</li>" }.join("\n") + "\n</ul>"))
    enclosure = item.add_element("enclosure")
    enclosure.add_attributes("url" => download_url, "length" => length, "type" => "application/octet-stream", "sparkle:edSignature" => signature)

    if first = feed.elements["item"]
      feed.insert_before(first, item)
    else
      feed.add_element(item)
    end

    Release.write_appcast(document)

    Dir.chdir(CATALOG) do
      run! "git", "add", "docs/appcast.xml"
      run! "git", "commit", "-m", "Publish TextMate #{version} to the #{channel} channel"
      run! "git", "push"
    end
  end

  # Tabs, one element per line, the way the feed is kept by hand.
  def self.write_appcast(document)
    formatter = REXML::Formatters::Pretty.new(1)
    formatter.compact = true
    output = +""
    formatter.write(document, output)
    File.write(APPCAST, output.gsub(/^ +/) { |spaces| "\t" * spaces.length } + "\n")
  end
end
