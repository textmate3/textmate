#import <ns/ns.h>

// The kVK_ virtual key codes live in HIToolbox, only reachable through the
// Carbon umbrella. Like ns.mm itself, this is a compile-time dependency and
// not a link one.
#import <Carbon/Carbon.h>

// to_s(NSEvent) reads only the key code and the modifier flags, then asks the
// system to translate the key code through the active keyboard layout. Letter
// and punctuation keys therefore produce layout-dependent strings, which is
// why every case here uses a key whose translation is identical on all
// layouts: return, tab, escape, space, the arrows, the function keys and the
// numeric keypad digits.
static NSEvent* KeyDown (unsigned short keyCode, NSEventModifierFlags flags)
{
	return [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:flags timestamp:0 windowNumber:0 context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:keyCode];
}

void test_command_return ()
{
	OAK_ASSERT_EQ(to_s(KeyDown(kVK_Return, NSEventModifierFlagCommand)), "@\r");
}

void test_control_escape ()
{
	OAK_ASSERT_EQ(to_s(KeyDown(kVK_Escape, NSEventModifierFlagControl)), "^\x1B");
}

void test_option_command_tab ()
{
	OAK_ASSERT_EQ(to_s(KeyDown(kVK_Tab, NSEventModifierFlagOption|NSEventModifierFlagCommand)), "~@\t");
}

void test_command_space ()
{
	OAK_ASSERT_EQ(to_s(KeyDown(kVK_Space, NSEventModifierFlagCommand)), "@ ");
}

// Arrow keys translate to the F700 range of function key characters, which is
// not ASCII, so the shift modifier stays literal instead of upcasing anything.
void test_shift_up_arrow ()
{
	OAK_ASSERT_EQ(to_s(KeyDown(kVK_UpArrow, NSEventModifierFlagShift)), "$");
}

void test_command_function_key ()
{
	OAK_ASSERT_EQ(to_s(KeyDown(kVK_F1, NSEventModifierFlagCommand)), "@");
}

// Modifier symbols come out in the canonical order the normalizer produces:
// numpad, control, option, shift, command.
void test_modifier_order ()
{
	OAK_ASSERT_EQ(to_s(KeyDown(kVK_DownArrow, NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagShift|NSEventModifierFlagCommand)), "^~$@");
}

// The numeric keypad flag is dropped by default, and preserved on request for
// keys that exist on a standard numeric keypad.
void test_numpad_flag_dropped ()
{
	OAK_ASSERT_EQ(to_s(KeyDown(kVK_ANSI_Keypad1, NSEventModifierFlagCommand|NSEventModifierFlagNumericPad)), "@1");
}

void test_numpad_flag_preserved ()
{
	OAK_ASSERT_EQ(to_s(KeyDown(kVK_ANSI_Keypad1, NSEventModifierFlagCommand|NSEventModifierFlagNumericPad), true), "#@1");
}
