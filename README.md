# FluminusCLI

[![Build Status](https://travis-ci.com/indocomsoft/fluminus_cli.svg?branch=master)](https://travis-ci.com/indocomsoft/fluminus_cli)
[![Coverage Status](https://coveralls.io/repos/github/indocomsoft/fluminus_cli/badge.svg?branch=master)](https://coveralls.io/github/indocomsoft/fluminus_cli?branch=master)

<sup><sub>F LumiNUS! IVLE ftw! Why fix what ain't broken?!</sub></sup>

Since IVLE was deprecated on AY2019/2020, and LumiNUS had consistently pushed back its schedule to release an API, I have decided to reverse-engineer the API used by the Angular front-end of LumiNUS.

I try to keep to best coding practices and use as little dependencies as possible. Do let me know if you have any suggestions!

PR's are welcome.

Code coverage is most likely to stay at 0% in the spirit of LumiNUS

![demo](demo.gif)

## Note for Windows Users
FluminusCLI is currently not compatible with Windows. I suggest using Fluminurs instead if all you need is file downloading: https://github.com/indocomsoft/fluminurs

Mostly this is because fluminus is designed with Unix in mind (use of `/tmp`, file name sanitisation that only looks for null and slash characters, etc.)

If you really need this badly, you can use docker: https://hub.docker.com/r/qjqqyy/fluminus (courtesy @qjqqyy)

## CLI Usage
The most important one, to download your files:

```bash
mkdir /tmp/fluminus
mix fluminus --download-to=/tmp/fluminus
```

This will download files of all your modules locally to the directory you speficied. To download all files again next time, simply do:

```bash
mix fluminus --download-to=/tmp/fluminus
```

More information can be found in the help page:
```bash
$ mix fluminus --help
mix fluminus [OPTIONS]

--verbose           Enable verbose mode
--show-errors       Show all errors instead of just swallowing them

--announcements     Show announcements
--files             Show files
--download-to=PATH  Download files to PATH

Only with --download-to
--webcasts          Download webcasts too
--lessons           Download files in the weekly lesson plans too
```

## Features
- Storing credentials (in plain text though)
- Listing of mods being taken and taught
- Syncing of workbin files
- Syncing of webcasts
- Syncing of files in weekly lesson plans
  - This includes downloading of multimedia files using ffmpeg


## Installation
### Requirements
- Elixir (tested with 1.10)
- Erlang/OTP (tested with 23.0)
- ffmpeg (optional, only to download multimedia files)

### CLI
1. Install elixir+erlang for your platform
2. Clone this repo
3. Get the dependencies:
```bash
mix deps.get
```
4. Fluminus CLI is available as a mix task:
```bash
mix fluminus
```

5. If you want to download multimedia files in the weekly lesson plans as well, you will need to download ffmpeg

Note that the first time running the mix task might be a bit slow because
the code has to be compiled first.
