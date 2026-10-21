# ---------------------------------------------------------------------------
# Plain English message library. One entry per check.
# Words in braces are filled in from the screen.
# ---------------------------------------------------------------------------

$Script:Rules = @{
    'zoom-reflow'         = @{ Title = 'Sideways scrolling at 400% zoom'; Wcag = '1.4.10'; WcagName = 'Reflow'; Dof = 'No side scroll on small screens'; Who = 'People with low vision who zoom in'
        What = 'At 400% zoom you have to scroll sideways to read this screen. The page is {width} pixels wide instead of fitting the window. The widest items are {items}.'
        Fix  = 'Let the layout stack into one column on narrow screens instead of using a fixed width.' }
    'zoom-reflow-table'   = @{ Title = 'Table or grid scrolls sideways at 400% zoom'; Wcag = '1.4.10'; WcagName = 'Reflow'; Dof = 'No side scroll on small screens'; Who = 'People with low vision who zoom in'
        What = 'At 400% zoom the screen scrolls sideways because of {items}. WCAG allows this for data tables and maps, so please confirm the rest of the screen still fits.'
        Fix  = 'If only the table scrolls, put it in its own scrolling box so the rest of the page fits the window.' }
    'zoom-clip-400'       = @{ Title = 'Text cut off at 400% zoom'; Wcag = '1.4.10'; WcagName = 'Reflow'; Dof = 'No side scroll on small screens'; Who = 'People with low vision who zoom in'
        What = 'At 400% zoom the text "{text}" is {how}, so part of it cannot be read.'
        Fix  = 'Let the box grow with its text instead of using a fixed size.' }
    'zoom-overlap-400'    = @{ Title = 'Text overlaps at 400% zoom'; Wcag = '1.4.10'; WcagName = 'Reflow'; Dof = 'No side scroll on small screens'; Who = 'People with low vision who zoom in'
        What = 'At 400% zoom the text "{text}" sits on top of "{other}", so neither can be read clearly.'
        Fix  = 'Give items room to move and stack when the screen gets narrow.' }
    'zoom-lost'           = @{ Title = 'Content disappears at 400% zoom'; Wcag = '1.4.10'; WcagName = 'Reflow'; Dof = 'No side scroll on small screens'; Who = 'People with low vision who zoom in'
        What = 'The text "{text}" shows at normal size but is hidden or off screen at 400% zoom.'
        Fix  = 'Keep it on screen at narrow widths, or move it into a menu that can still be opened.' }
    'zoom-clip-200'       = @{ Title = 'Text cut off at 200% zoom'; Wcag = '1.4.4'; WcagName = 'Resize Text'; Dof = 'Zoom 200% layout intact'; Who = 'People with low vision who zoom in'
        What = 'At 200% zoom the text "{text}" is {how}, so part of it cannot be read.'
        Fix  = 'Let the box grow with its text instead of using a fixed size.' }
    'zoom-overlap-200'    = @{ Title = 'Text overlaps at 200% zoom'; Wcag = '1.4.4'; WcagName = 'Resize Text'; Dof = 'Zoom 200% layout intact'; Who = 'People with low vision who zoom in'
        What = 'At 200% zoom the text "{text}" sits on top of "{other}".'
        Fix  = 'Give items room to move when the text gets bigger.' }
    'spacing-clip'        = @{ Title = 'Text cut off with wider spacing'; Wcag = '1.4.12'; WcagName = 'Text Spacing'; Dof = ''; Who = 'People with dyslexia or low vision who use custom spacing'
        What = 'When line and letter spacing are increased, the text "{text}" is {how}.'
        Fix  = 'Avoid fixed heights and widths on boxes that hold text.' }
    'spacing-overlap'     = @{ Title = 'Text overlaps with wider spacing'; Wcag = '1.4.12'; WcagName = 'Text Spacing'; Dof = ''; Who = 'People with dyslexia or low vision who use custom spacing'
        What = 'When line and letter spacing are increased, the text "{text}" runs into "{other}".'
        Fix  = 'Avoid fixed heights and positions on boxes that hold text.' }
    'kb-unreachable'      = @{ Title = 'Cannot be reached with the keyboard'; Wcag = '2.1.1'; WcagName = 'Keyboard'; Dof = 'Keyboard only operation'; Who = 'People who cannot use a mouse'
        What = '{name} can be clicked with a mouse, but pressing Tab never moves to it.'
        Fix  = 'Make it a real button or link, or allow it to take keyboard focus.' }
    'kb-fake'             = @{ Title = 'Looks like a button but is not one'; Wcag = '4.1.2'; WcagName = 'Name, Role, Value'; Dof = 'ARIA on custom controls'; Who = 'Keyboard and screen reader users'
        What = '{name} works when clicked with a mouse, but the keyboard cannot reach it and screen readers do not call it a button.'
        Fix  = 'Use a real button, or add button behavior for screen readers and the keyboard.' }
    'kb-fake-check'       = @{ Title = 'Might be clickable but is not a button'; Wcag = '2.1.1'; WcagName = 'Keyboard'; Dof = 'Make interactive elements easy to identify'; Who = 'Keyboard and screen reader users'
        What = '{name} shows the hand pointer like something you can click, but it is not a link or button. If it does something when clicked, keyboard users cannot use it.'
        Fix  = 'If it can be clicked, make it a real button. If not, remove the hand pointer.' }
    'kb-trap'             = @{ Title = 'Keyboard gets stuck'; Wcag = '2.1.2'; WcagName = 'No Keyboard Trap'; Dof = 'Exit popups with Esc or Tab'; Who = 'People who cannot use a mouse'
        What = 'Once focus reaches {name}, pressing Tab keeps cycling through the same {count} items and Esc does not get out.'
        Fix  = 'Let Tab and Esc move focus out of this area.' }
    'kb-focus-invisible'  = @{ Title = 'Cannot see where the keyboard is'; Wcag = '2.4.7'; WcagName = 'Focus Visible'; Dof = 'Visible focus outline'; Who = 'Keyboard users and people with low vision'
        What = 'When {name} has keyboard focus, nothing on the screen changes to show it.'
        Fix  = 'Show a clear outline or highlight on whatever has keyboard focus.' }
    'kb-focus-hidden-item' = @{ Title = 'Keyboard lands on something invisible'; Wcag = '2.4.7'; WcagName = 'Focus Visible'; Dof = 'Visible focus outline'; Who = 'Keyboard users'
        What = 'Pressing Tab moves to {name}, but it cannot be seen on the screen, so users lose track of where they are.'
        Fix  = 'Hide it from the keyboard too when it is hidden, or show it when it gets focus.' }
    'kb-obscured'         = @{ Title = 'Focused item hidden behind a header or banner'; Wcag = '2.4.11'; WcagName = 'Focus Not Obscured (Minimum)'; Dof = ''; Who = 'Keyboard users'
        What = 'When {name} has keyboard focus it is completely covered by {cover}.'
        Fix  = 'Keep focused items from sliding under sticky headers or footers.' }
    'kb-order'            = @{ Title = 'Tab order jumps around'; Wcag = '2.4.3'; WcagName = 'Focus Order'; Dof = 'Tab order top left to bottom right'; Who = 'Keyboard and screen reader users'
        What = 'Pressing Tab jumps {example}. The numbered picture shows the full order.'
        Fix  = 'Make Tab move top left to bottom right, in the same order things appear on screen.' }
    'kb-skip'             = @{ Title = 'No way to skip past the menu'; Wcag = '2.4.1'; WcagName = 'Bypass Blocks'; Dof = 'HTML5 grouping tags'; Who = 'Keyboard and screen reader users'
        What = 'Keyboard users have to tab through {count} menu items before reaching the content, on every screen.'
        Fix  = 'Add a Skip to Main Content link at the top and mark the main content area.' }
    'sr-unnamed'          = @{ Title = 'Control has no name'; Wcag = '4.1.2'; WcagName = 'Name, Role, Value'; Dof = 'Screen reader reads labels and buttons'; Who = 'Screen reader and voice control users'
        What = 'The screen reader only says "{role}" for {name}, with no name, so users cannot tell what it does.'
        Fix  = 'Give it a name that says what it does. The name can be hidden from sight and still be read aloud.' }
    'sr-no-label'         = @{ Title = 'Field has no label'; Wcag = '1.3.1'; WcagName = 'Info and Relationships'; Dof = 'Fields labeled and announced'; Who = 'Screen reader users'
        What = 'The screen reader reads {name} with no label, so users do not know what to type.'
        Fix  = 'Tie the visible label to the field.' }
    'sr-placeholder'      = @{ Title = 'Field label disappears when typing'; Wcag = '3.3.2'; WcagName = 'Labels or Instructions'; Dof = 'Label and input pairs'; Who = 'People with memory or attention difficulties, and screen reader users'
        What = 'The field "{name}" only has gray hint text inside it. The hint vanishes once someone starts typing.'
        Fix  = 'Add a visible label above or beside the field.' }
    'sr-required'         = @{ Title = 'Required field not announced'; Wcag = '3.3.2'; WcagName = 'Labels or Instructions'; Dof = 'Fields labeled and announced'; Who = 'Screen reader users'
        What = 'The field "{name}" is marked required on screen, but the screen reader does not say it is required.'
        Fix  = 'Mark the field as required so it is announced.' }
    'sr-vague'            = @{ Title = 'Links all say the same thing'; Wcag = '2.4.4'; WcagName = 'Link Purpose (In Context)'; Dof = 'Meaningful link and button text'; Who = 'Screen reader users who browse a list of links'
        What = '{count} links or buttons all say "{name}" but go to different places.'
        Fix  = 'Make each one say where it goes, like View Budget Details.' }
    'sr-label-in-name'    = @{ Title = 'Spoken name does not match the words on screen'; Wcag = '2.5.3'; WcagName = 'Label in Name'; Dof = 'Consistent button and link labels'; Who = 'Voice control users who say what they see'
        What = 'The button shows "{visible}" but screen readers and voice control know it as "{spoken}".'
        Fix  = 'Make the spoken name start with the same words shown on screen.' }
    'sr-img-noalt'        = @{ Title = 'Image has no description'; Wcag = '1.1.1'; WcagName = 'Non-text Content'; Dof = 'Alternative text for images'; Who = 'Blind users'
        What = 'This image has no description, so a screen reader either skips it or reads out a file name.'
        Fix  = 'Add a short description, or mark it as decorative if it adds nothing.' }
    'sr-img-badalt'       = @{ Title = 'Image description is not helpful'; Wcag = '1.1.1'; WcagName = 'Non-text Content'; Dof = 'Alternative text for images'; Who = 'Blind users'
        What = 'This image is described only as "{alt}", which does not say what it shows.'
        Fix  = 'Describe what the image shows or why it is there.' }
    'sr-no-h1'            = @{ Title = 'No main heading'; Wcag = '1.3.1'; WcagName = 'Info and Relationships'; Dof = 'Semantic markup'; Who = 'Screen reader users'
        What = 'The screen has no main heading, so screen reader users cannot jump straight to the start of the content.'
        Fix  = 'Add one main heading that names the screen.' }
    'sr-heading-skip'     = @{ Title = 'Heading levels skip'; Wcag = '1.3.1'; WcagName = 'Info and Relationships'; Dof = 'Semantic markup'; Who = 'Screen reader users'
        What = 'Headings jump from level {from} to level {to} at "{text}", which makes the page outline confusing.'
        Fix  = 'Use heading levels in order without skipping.' }
    'sr-fake-heading'     = @{ Title = 'Looks like a heading but is not coded as one'; Wcag = '1.3.1'; WcagName = 'Info and Relationships'; Dof = 'Section header text'; Who = 'Screen reader users'
        What = '{text} look like section titles, but screen readers treat them as plain text, so users cannot jump between sections.'
        Fix  = 'Code section titles as headings.' }
    'sr-landmarks'        = @{ Title = 'Page areas not marked'; Wcag = '1.3.1'; WcagName = 'Info and Relationships'; Dof = 'HTML5 grouping tags'; Who = 'Screen reader users'
        What = 'The screen has no {regions} area marked for screen readers, so users cannot jump to it.'
        Fix  = 'Mark the header, menu, main content and footer areas.' }
    'sr-table-headers'    = @{ Title = 'Table has no column headings'; Wcag = '1.3.1'; WcagName = 'Info and Relationships'; Dof = 'Table headings'; Who = 'Screen reader users'
        What = 'The table {table} has no column headings tied to its cells, so a screen reader reads numbers with no context.'
        Fix  = 'Give every column a heading cell.' }
    'sr-reading-order'    = @{ Title = 'Reading order does not match the screen'; Wcag = '1.3.2'; WcagName = 'Meaningful Sequence'; Dof = 'Logical reading order'; Who = 'Screen reader users'
        What = 'The screen reader reads "{a}" before "{b}", but "{b}" appears above it on screen.'
        Fix  = 'Arrange the page so the reading order matches what people see.' }
    'sr-no-title'         = @{ Title = 'Screen has no title'; Wcag = '2.4.2'; WcagName = 'Page Titled'; Dof = ''; Who = 'Screen reader users switching between tabs'
        What = 'This screen has no title, so the browser tab and screen readers have nothing to announce.'
        Fix  = 'Give each screen its own title.' }
    'sr-dup-title'        = @{ Title = 'Several screens share one title'; Wcag = '2.4.2'; WcagName = 'Page Titled'; Dof = ''; Who = 'Screen reader users switching between tabs'
        What = '{count} screens all have the title "{title}", so users cannot tell them apart.'
        Fix  = 'Give each screen its own title.' }
    'sr-no-lang'          = @{ Title = 'Page language not set'; Wcag = '3.1.1'; WcagName = 'Language of Page'; Dof = ''; Who = 'Screen reader users'
        What = 'The page does not say it is in English, so screen readers may pronounce words wrong.'
        Fix  = 'Set the page language to English.' }
    'sr-hidden-focusable' = @{ Title = 'Hidden from screen readers but still reachable'; Wcag = '4.1.2'; WcagName = 'Name, Role, Value'; Dof = 'Screen reader reads content'; Who = 'Screen reader users'
        What = 'Keyboard focus can land on {name}, but it is hidden from screen readers, so they hear nothing.'
        Fix  = 'Either show it to screen readers or remove it from the keyboard order.' }
    'vis-target-size'     = @{ Title = 'Click targets too small'; Wcag = '2.5.8'; WcagName = 'Target Size (Minimum)'; Dof = ''; Who = 'People with tremors or limited hand control'
        What = '{count} clickable items are smaller than 24 by 24 pixels and packed close together. For example {name} is {w} by {h} pixels.'
        Fix  = 'Make them bigger or add space around them.' }
    'vis-sensory'         = @{ Title = 'Instructions rely on color or position'; Wcag = '1.3.3'; WcagName = 'Sensory Characteristics'; Dof = 'Avoid relying on color alone'; Who = 'Blind and color blind users'
        What = 'The screen says "{quote}", which only works if you can see the color, shape or position.'
        Fix  = 'Refer to things by their name, like click the Save button.' }
    'tool-error'          = @{ Title = 'Part of the test could not run'; Wcag = ''; WcagName = ''; Dof = ''; Who = 'Nobody, this is a note about the tool'
        What = 'The {module} test could not finish on this screen. {detail}'
        Fix  = 'Run the test on this screen again. If it keeps happening, send the Run Log to whoever maintains the tool.' }
}

# WCAG 2.2 Level A and AA. How = Auto (tested here), Later (coming in a later phase), Person (needs a human).
$Script:WcagList = @(
    @('1.1.1', 'Non-text Content', 'A', 'Auto'), @('1.2.1', 'Audio-only and Video-only (Prerecorded)', 'A', 'Person'), @('1.2.2', 'Captions (Prerecorded)', 'A', 'Person'),
    @('1.2.3', 'Audio Description or Media Alternative (Prerecorded)', 'A', 'Person'), @('1.2.4', 'Captions (Live)', 'AA', 'Person'), @('1.2.5', 'Audio Description (Prerecorded)', 'AA', 'Person'),
    @('1.3.1', 'Info and Relationships', 'A', 'Auto'), @('1.3.2', 'Meaningful Sequence', 'A', 'Auto'), @('1.3.3', 'Sensory Characteristics', 'A', 'Auto'),
    @('1.3.4', 'Orientation', 'AA', 'Later'), @('1.3.5', 'Identify Input Purpose', 'AA', 'Later'), @('1.4.1', 'Use of Color', 'A', 'Later'),
    @('1.4.2', 'Audio Control', 'A', 'Person'), @('1.4.3', 'Contrast (Minimum)', 'AA', 'Later'), @('1.4.4', 'Resize Text', 'AA', 'Auto'),
    @('1.4.5', 'Images of Text', 'AA', 'Person'), @('1.4.10', 'Reflow', 'AA', 'Auto'), @('1.4.11', 'Non-text Contrast', 'AA', 'Later'),
    @('1.4.12', 'Text Spacing', 'AA', 'Auto'), @('1.4.13', 'Content on Hover or Focus', 'AA', 'Later'), @('2.1.1', 'Keyboard', 'A', 'Auto'),
    @('2.1.2', 'No Keyboard Trap', 'A', 'Auto'), @('2.1.4', 'Character Key Shortcuts', 'A', 'Person'), @('2.2.1', 'Timing Adjustable', 'A', 'Later'),
    @('2.2.2', 'Pause, Stop, Hide', 'A', 'Person'), @('2.3.1', 'Three Flashes or Below Threshold', 'A', 'Person'), @('2.4.1', 'Bypass Blocks', 'A', 'Auto'),
    @('2.4.2', 'Page Titled', 'A', 'Auto'), @('2.4.3', 'Focus Order', 'A', 'Auto'), @('2.4.4', 'Link Purpose (In Context)', 'A', 'Auto'),
    @('2.4.5', 'Multiple Ways', 'AA', 'Person'), @('2.4.6', 'Headings and Labels', 'AA', 'Person'), @('2.4.7', 'Focus Visible', 'AA', 'Auto'),
    @('2.4.11', 'Focus Not Obscured (Minimum)', 'AA', 'Auto'), @('2.5.1', 'Pointer Gestures', 'A', 'Person'), @('2.5.2', 'Pointer Cancellation', 'A', 'Person'),
    @('2.5.3', 'Label in Name', 'A', 'Auto'), @('2.5.4', 'Motion Actuation', 'A', 'Person'), @('2.5.7', 'Dragging Movements', 'AA', 'Person'),
    @('2.5.8', 'Target Size (Minimum)', 'AA', 'Auto'), @('3.1.1', 'Language of Page', 'A', 'Auto'), @('3.1.2', 'Language of Parts', 'AA', 'Person'),
    @('3.2.1', 'On Focus', 'A', 'Person'), @('3.2.2', 'On Input', 'A', 'Person'), @('3.2.3', 'Consistent Navigation', 'AA', 'Later'),
    @('3.2.4', 'Consistent Identification', 'AA', 'Later'), @('3.2.6', 'Consistent Help', 'A', 'Later'), @('3.3.1', 'Error Identification', 'A', 'Later'),
    @('3.3.2', 'Labels or Instructions', 'A', 'Auto'), @('3.3.3', 'Error Suggestion', 'AA', 'Later'), @('3.3.4', 'Error Prevention (Legal, Financial, Data)', 'AA', 'Person'),
    @('3.3.7', 'Redundant Entry', 'A', 'Person'), @('3.3.8', 'Accessible Authentication (Minimum)', 'AA', 'Person'), @('4.1.2', 'Name, Role, Value', 'A', 'Auto'),
    @('4.1.3', 'Status Messages', 'AA', 'Later')
)

$Script:ManualChecks = @(
    @('1.1.1', 'Read the image descriptions in the transcripts file and confirm each one makes sense.'),
    @('1.2.1 to 1.2.5', 'If the app has any video or audio, confirm captions and transcripts exist.'),
    @('1.4.2', 'If anything plays sound on its own for more than 3 seconds, confirm it can be paused or muted.'),
    @('1.4.5', 'Look for pictures of words, like text inside a banner image. Real text should be used instead.'),
    @('2.1.4', 'Press single letter keys while not in a text box. Nothing should happen unless it can be turned off.'),
    @('2.2.2', 'Anything that moves, scrolls or updates by itself for more than 5 seconds needs a pause button.'),
    @('2.3.1', 'Nothing should flash more than 3 times a second.'),
    @('2.4.5', 'There should be more than one way to find a screen, such as a menu and a search.'),
    @('2.4.6', 'Headings and labels should describe what follows them.'),
    @('2.5.1 and 2.5.2', 'Swipes or pinches need a simple tap or click option, and actions should fire when the click is released, not pressed.'),
    @('2.5.7', 'Anything you drag needs a click alternative, like up and down buttons.'),
    @('3.2.1 and 3.2.2', 'Tabbing into a field or picking a dropdown value should not jump to a new screen on its own.'),
    @('3.3.4', 'Final submits that save money, legal or important data need a review or confirm step.'),
    @('3.3.7', 'Multi step forms should not ask for the same information twice.'),
    @('3.3.8', 'The login should not need a puzzle, and should allow pasting passwords and password managers.')
)
