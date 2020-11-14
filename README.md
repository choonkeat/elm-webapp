# Fullstack

A setup for writing http based, client-server app in elm, inspired wholly by [Lamdera](https://lamdera.app)

## Getting started

```
npx elm-fullstack element hello-app
```

This will create a skeleton file directory structure

```
hello-app
├── Makefile
├── index.js
└── src
    ├── Client.elm
    ├── Server.elm
    └── Types.elm

1 directory, 5 files
```

- `src/Client.elm` is where our [Browser.element](https://package.elm-lang.org/packages/elm/browser/latest/Browser#element) resides. The only exception is, this app includes a built-in `sendToServer` [Task](https://package.elm-lang.org/packages/elm/core/latest/Task)
    - to generate [Browser.document](https://package.elm-lang.org/packages/elm/browser/latest/Browser#document) or [Browser.application](https://package.elm-lang.org/packages/elm/browser/latest/Browser#application) instead, use either commands

    ```
    npx elm-fullstack document hello-app
    npx elm-fullstack application hello-app
    ```

- `src/Server.elm` is where our elm [Platform.worker](https://package.elm-lang.org/packages/elm/core/latest/Platform#worker) resides. It serves your SPA by default, and can respond to `sendToServer`
- `src/Types.elm` includes the custom types that defines the protocol between Client and Server
- `index.js` boots up our Server.elm and listens to http requests at port 8000

## License

Copyright © 2020 Chew Choon Keat

Distributed under the MIT license.
