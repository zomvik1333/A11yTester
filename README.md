# A11y Tester

A tool that tests a web app for WCAG 2.2 accessibility the way a person with a disability would use it, then writes a plain English Word report.

You do not need to know how to code. Nothing is downloaded or installed, and nothing leaves your computer. It only uses things already on a Windows computer, which are PowerShell, Microsoft Edge (or Chrome) and your Documents folder.

## What it tests

- **Zoom.** Whether the screen still works at 200% and 400% zoom, with nothing cut off, overlapping or lost.
- **Text spacing.** Whether text survives the extra spacing some people with dyslexia use.
- **Keyboard only.** Whether every button and link can be reached with the Tab key, whether you can always see where the keyboard is, whether the order makes sense, and whether the keyboard ever gets stuck.
- **Screen reader.** What a screen reader like NVDA or JAWS would announce, including buttons with no name, fields with no label, missing image descriptions, headings, tables and reading order.

It skips the basic rule scans that WAVE and axe already do.

## Get it onto your computer

Pick whichever works where you are.

1. **Git Clone in VS Code.** Press Ctrl+Shift+P, type Git Clone, paste the link to this repo and choose your Documents folder.
2. **Copy and paste.** Open `A11yTester.ps1` in this repo, click **Raw**, press Ctrl+A then Ctrl+C. In VS Code make a new file, paste, and save it as `A11yTester.ps1` in a folder such as `Documents\A11y Tester`. That one file is the whole tool.

## Run it

In VS Code open the folder with `A11yTester.ps1`, choose **Terminal**, **New Terminal**, and paste this line.

```
powershell -ExecutionPolicy Bypass -File .\A11yTester.ps1
```

That only relaxes the script rule for this one run. To skip the terminal next time, double click `Start Test.bat` (if you copied by hand, make a file with that name next to the tool containing the line `powershell -ExecutionPolicy Bypass -File "%~dp0A11yTester.ps1"`).

### The first time

It asks for the app name and the dev or test link, then saves them. Next time you just pick the app from a list.

### Every time

1. Pick the app and pick a mode.
2. Edge opens in its own clean window. Log in like normal, MFA included.
3. Click the green **I'm Logged In** button in the bottom right corner.
4. Go to a screen and click **Test This Screen**. Keep your hands off for about 30 seconds while it zooms, tabs and listens.
5. Repeat for each screen, then click **Done**.
6. The Word report and the results folder open on their own.

### Modes

| Mode | Use it when |
| --- | --- |
| 1. I will click through | Most apps. You go to each screen and press Test This Screen. The tool records your clicks so the report can give directions to every screen. |
| 2. Test a list of links | Apps where each screen has its own web address. Paste the links, or point `LinksFile` in the settings at a text file with one link per line. |

Explore the whole app on its own is planned for the next version.

## A11y Snippet

A lighter version that runs inside Edge developer tools. Nothing runs outside the browser, so there is no PowerShell and no remote control of Edge. It records your clicks and tests each screen as you go, you do the zooming, and the report goes to your clipboard for pasting into Word. It takes no screenshots, but each issue has a Show Me button that outlines the problem on screen.

### Save it once

1. Open the snippet at https://raw.githubusercontent.com/zomvik1333/A11yTester/main/A11ySnippet.js and press Ctrl+A, then Ctrl+C.
2. Open your app in Edge and press F12 to open developer tools.
3. Click the **Sources** tab. On the left, click **Snippets** (it may be behind the >> arrows). Click **New snippet** and name it A11y.
4. Click in the empty editor and press Ctrl+V. If Edge warns you about pasting, type `allow pasting` and press Enter, then paste again.
5. Press Ctrl+S to save. Edge keeps the snippet for next time.

### Use it

1. Log in to your app in Edge and go to the first screen you want to check.
2. Press F12, then Ctrl+P, type `!A11y` and press Enter. The panel appears in the bottom right corner and tests the screen right away. You can close developer tools now.
3. Just use the app. The snippet records what you click and tests each new screen on its own, a second or two after it loads. The panel fills in the directions to each screen for you.
4. If your app reloads the whole page when you move between screens, the browser clears the snippet. On each new page press F12, then Ctrl+P, type `!A11y` and press Enter again. Your clicks are still remembered and the new page is tested right away.
5. For the zoom check on a screen, press Ctrl and + until the width in the panel shows 320 or less, then click **Check 400%**. Press Ctrl and 0 to go back to normal.
6. When you are done, click **Copy Report** and paste into a blank Word document. If copying is blocked, click **Open Report**, then press Ctrl+A and Ctrl+C in the new tab.

Results and recorded clicks are kept until you click **Clear All**, so clear them before starting a new app. Click **Pause Auto Testing** if you want to move around without testing, and **Test Again** to retest a screen after fixing the name or directions.

**Screen Reader View** opens what a screen reader would say on the current screen.

### What the snippet cannot do

Because it cannot press real keys, it cannot detect keyboard traps or focus hidden behind sticky headers. Those two are added to the Needs a Person list. Its screen reader view is worked out from the page code rather than read from the browser, so it is a little less exact than the full tool.

## What you get

A dated folder in `Documents\A11y Tester Results\<App name>` with these files.

- **Accessibility Report.docx.** Leads with Not Compliant or No Automated Failures Found, then the top fixes, then every issue with directions, a screenshot with the problem outlined in red, what is wrong in plain words, who it affects and the recommended fix. It ends with the manual checklist and a WCAG 2.2 AA scorecard.
- **Issue List.csv.** One row per issue. Opens in Excel and can be loaded into Azure DevOps.
- **Screen Reader Transcripts.docx.** What a screen reader would say on each screen.
- **Screenshots** and **Run Log.txt.**

Issue numbers stay the same between runs, so ADA 014 means the same problem next month, and the report shows what was fixed since the last run.

## Settings

Each app has a settings file in `Documents\A11y Tester Data\Apps`. Open it in Notepad.

| Setting | What it does |
| --- | --- |
| AppLink | The dev or test link to open |
| ProductionAddresses | The tool refuses any link starting with these. Separate several with a comma |
| LinksFile | A text file of links for mode 2 |
| MaxTabStops | How many Tab presses to try per screen, 150 by default |
| ClearLoginAfterRun | yes deletes the browser login when the run ends |
| TestedBy, ResultsFolder | Shown on the report, and where results go |

## If something goes wrong

| What you see | What to do |
| --- | --- |
| The browser started but would not let the tool connect | A policy blocks it. In Edge go to `edge://policy` and look for RemoteDebuggingAllowed or DeveloperToolsAvailability. Ask IT, or try Chrome with `-BrowserPath` |
| Running scripts is disabled on this system | Use the full line above with `-ExecutionPolicy Bypass`. If that is blocked too, ask IT to allow this one script. It is plain text, so they can read it first |
| A test could not finish on a screen | The report notes it and the Run Log has the details. Test that screen again |
| Popups that open in a new window | Not followed yet. Test the screen inside the main window |

## Limits

Automated testing cannot prove an app is compliant. The report always lists the WCAG items that need a person, such as whether image descriptions make sense. The screen reader transcript matches NVDA and JAWS closely but not word for word.

## For developers

The tool is one PowerShell file built from small source files.

- `src/driver` talks to the browser through the Chrome DevTools Protocol using only built in .NET classes
- `src/browser` holds the JavaScript checks that run inside the page
- `src/report` holds the message library, the scorecard and a small .docx writer
- `build.ps1` stitches them into `A11yTester.ps1`, which must stay plain ASCII so copy and paste works
- `src/snippet` holds the extra code for A11y Snippet, which reuses the browser checks
- `tests/Run-Tests.ps1`, `tests/Run-SnippetTests.ps1` and `tests/Run-SnippetAutoTest.ps1` run both versions against `test-site`, where every page has planted problems except `clean.html`

Edit the `src` files, run `build.ps1`, then run the tests.

Works with Windows PowerShell 5.1 and PowerShell 7. MIT licensed.
