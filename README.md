# YoloApp: A Desktop Sample App

This application is an example of an Elixir LiveView based desktop application.
It uses the elixir-desktop library to create a web-technology based desktop app.

Fork from <https://github.com/elixir-desktop/desktop-example-app>

## Changes in 1.0

- Updated to Phoenix 1.6 with esbuild+dart_scss
- Added iOS platform example wrapper (see https://github.com/elixir-desktop/ios-example-app)
- Added Android platform example wrapper (see https://github.com/elixir-desktop/android-example-app)

## General notes

To run this app you need at least Erlang 24 and recent builds of wxWidgets.

## Dependencies

This example assumes you've got installed:

- git
- asdf
- Erlang, at least OTP 24

If you want to build for iOS you'll also need xcode and in order to build for Android you'll need the
Android Studio.

## Run locally

```bash
asdf plugin add direnv
asdf plugin add elixir
asdf plugin add nodejs
asdf install
asdf exec direnv allow .envrc
```

```bash
mix deps.get
cd assets && npm install && cd ..
mix assets.deploy
iex -S mix
```

## Screenshots

![yolo](/nodeploy/yolo.png?raw=true)
