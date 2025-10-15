# Bundling Whisper models with the macOS client

The macOS client now looks for Whisper models that ship inside the application bundle before it attempts to download them from the network. To avoid a large download during the first launch, add the desired model folder to the app before you create the DMG.

## Preparing the model folder

1. On a development machine run the app once and let WhisperKit finish downloading the desired model (for example `medium`).
2. After the download is complete locate the folder at:
   ```
   ~/Library/Application Support/WhisperKit/<model-folder>
   ```
   The folder name usually contains the model variant, e.g. `openai_whisper-medium` or `openai_whisper-medium-q5_0`.
3. Copy that folder into the repository under:
   ```
   mac-client/GHOSTDeskUI/GHOSTDeskUI/Resources/WhisperModels/
   ```
   You can keep multiple models in this folder; each one will be copied into the user’s `Application Support/WhisperKit` directory on first launch.

> ⚠️ The actual model data is large (around 2 GB for `medium`) and should **not** be committed to Git. Instead, copy it into the folder locally right before building the release artifacts.

## Building the DMG

When the app starts it checks the bundled `WhisperModels` folder:

- If a matching model folder is found it is copied into `~/Library/Application Support/WhisperKit` and loaded directly.
- If no bundled model is present the app falls back to the previous behaviour and downloads the model from the network.

Therefore, as long as the folder exists inside the app bundle, users will have the model available immediately after dragging the app out of the DMG.
