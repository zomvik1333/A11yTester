# Security notes for reviewers

A11y Tester is a single plain text PowerShell script. This page explains exactly what it touches.

## What it does

- Starts Microsoft Edge (or Chrome) with a separate, empty profile in `Documents\A11y Tester Data\Browser Profile`.
- Connects to that browser on 127.0.0.1 only, through the browser's own remote debugging port. The port is picked at random by the browser and never listens on the network.
- Opens the dev or test link the user typed. The user logs in by hand. The tool never sees, stores or replays passwords.
- Reads the page, resizes the view, presses Tab and Escape, and takes screenshots. It does not click buttons, type into fields or submit forms. The only key presses are Tab and Escape.
- Writes a Word report, a CSV, screenshots and a log to `Documents\A11y Tester Results`.
- Deletes the browser profile, including cookies, when the run ends, unless `ClearLoginAfterRun = no`.

## What it does not do

- No downloads, installs, updates or telemetry.
- No network calls of its own. The only traffic is the browser loading the app the user chose.
- No AI services.
- No third party libraries. It uses Windows PowerShell, .NET classes built into Windows, and the browser.
- No admin rights. No registry or system setting changes.

## Guard rails

- Any link starting with an address in `ProductionAddresses` is refused.
- Screenshots may show test data. Treat the results folder like any other work file.

## Reviewing the code

Every line is in `A11yTester.ps1`. It is generated from the `src` folder by `build.ps1`, so reviewers can read either. `tests/Run-Tests.ps1` proves each check against a sample site with planted problems.
