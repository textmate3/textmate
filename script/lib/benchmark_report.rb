# Shared by the benchmark scripts: the statistics over a run's samples and the
# markdown table that reports them.

def median(values)
  sorted = values.sort
  middle = sorted.size / 2
  sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
end

# Number columns are right aligned so the digits line up, text columns left.
# A column is text when its header says so.
def markdown_table(headers, rows, text_columns: [headers.first])
  widths = headers.each_index.map { |column| ([headers[column]] + rows.map { it[column].to_s }).map(&:size).max }
  numeric = headers.map { !text_columns.include?(it) }
  line = ->(cells) { "| #{cells.each_with_index.map { |cell, column| numeric[column] ? cell.to_s.rjust(widths[column]) : cell.to_s.ljust(widths[column]) }.join(' | ')} |" }
  separator = "|#{headers.each_index.map { |column| numeric[column] ? "#{'-' * (widths[column] + 1)}:" : "-#{'-' * (widths[column] + 1)}" }.join('|')}|"
  [line.call(headers), separator, *rows.map { line.call(it) }].join("\n")
end
