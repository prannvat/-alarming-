# Setup Guide for Alarming

It looks like Flutter is not installed or configured on your system. Follow these steps to get up and running.

## 1. Install Flutter (macOS)

1.  **Download the Flutter SDK**:
    Go to [docs.flutter.dev/get-started/install/macos](https://docs.flutter.dev/get-started/install/macos) and download the latest stable release for your processor (Intel or Apple Silicon).

2.  **Extract the SDK**:
    Unzip the file and move the `flutter` folder to a location like `~/development/flutter`.

3.  **Update your PATH**:
    Open your terminal configuration file (`~/.zshrc` since you are using zsh).
    ```bash
    nano ~/.zshrc
    ```
    Add the following line (adjust the path to where you moved the flutter folder):
    ```bash
    export PATH="$PATH:$HOME/development/flutter/bin"
    ```
    Save and exit (Ctrl+O, Enter, Ctrl+X).

4.  **Apply Changes**:
    Restart your terminal or run:
    ```bash
    source ~/.zshrc
    ```

5.  **Verify Installation**:
    Run:
    ```bash
    flutter doctor
    ```

## 2. Run the App

Once Flutter is installed:

1.  Navigate to the project folder:
    ```bash
    cd alarming
    ```

2.  Get dependencies:
    ```bash
    flutter pub get
    ```

3.  Run the app:
    ```bash
    flutter run
    ```
