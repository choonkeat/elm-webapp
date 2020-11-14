global.XMLHttpRequest = require('xhr2')

// define http server
const http = require('http')
const fullUrl = require('full-url')
const nodeStatic = require('node-static')
const fileServer = new nodeStatic.Server('./public')
const WebSocketServer = require('websocket').server

const fs = require('fs')
const crypto = require('crypto')
const hash = crypto.createHash('sha256')
const jsData = fs.readFileSync('public/assets/client.js', { encoding: 'utf8' })
hash.update(jsData)
const jsSha = hash.digest('hex')

function httpServer (app) {
  if (!app.ports) return console.log('no ports!')

  // Start http server, accept requests and pass to Elm
  const server = http.createServer((req, res) => {
    const body = [] // https://nodejs.org/en/docs/guides/anatomy-of-an-http-transaction/#request-body
    req.on('data', (chunk) => {
      body.push(chunk)
    }).on('end', () => {
      fileServer.serve(req, res, function (e) {
        // if static file is found by fileServer, serve it
        if (!e || e.status !== 404) return

        // otherwise, Fullstack.Server will handle the request
        const contentType = req.headers['content-type'] || ''
        const encoding = (contentType.match(/; charset=(\S+)/) || ['', 'utf8'])[1] // charset or default to "utf8"
        const bodyString = Buffer.concat(body).toString(encoding)
        app.ports.onHttpRequest.send({
          response: res, // this value will be used by "onHttpResponse" below
          method: req.method,
          url: fullUrl(req),
          path: req.url,
          body: bodyString,
          headers: req.headers
        })
      })
    }).resume()
  })
  app.ports.onHttpResponse.subscribe(({ statusCode, body, headers, request }) => {
    console.log('[http] onHttpResponse status=', statusCode, Buffer.byteLength(body), 'bytes')
    request.response.writeHead(statusCode, { ...headers, 'Content-Length': Buffer.byteLength(body) })
    request.response.end(body)
  })

  if (app.ports.writeWs) {
    app.ports.writeWs.subscribe(({ key, connection, body }) => {
      console.log('[ws] writeWs key=', key, body)
      connection.sendUTF(body)
    })
  }

  var wsServer
  if (app.ports.onWebsocketEvent) {
    wsServer = new WebSocketServer({
      // WebSocket server is tied to a HTTP server. WebSocket request is just
      // an enhanced HTTP request. For more info http://tools.ietf.org/html/rfc6455#page-6
      httpServer: server
    })

    // Start websocket server, accept requests and pass to Elm
    wsServer.on('request', function (request) {
      console.log('[ws] Connection from origin ' + request.origin + '.', request.key)

      // accept connection - you should check 'request.origin' to make sure that
      // client is connecting from your website
      // (http://en.wikipedia.org/wiki/Same_origin_policy)
      if (request.origin !== 'http://localhost:8000' && false) {
        request.reject()
        console.log((new Date()) + ' Connection from origin ' + request.origin + ' rejected.')
        return
      }

      var connection = request.accept(null, request.origin)
      app.ports.onWebsocketEvent.send({
        open: connection,
        key: request.key,
        headers: (request.httpRequest || {}).headers
      })

      // user sent some message
      connection.on('message', function (payload) {
        console.log('[ws] payload', payload)
        app.ports.onWebsocketEvent.send({
          message: connection,
          key: request.key,
          payload: payload
        })
      })
      // user disconnected
      // https://github.com/theturtle32/WebSocket-Node/blob/1f7ffba2f7a6f9473bcb39228264380ce2772ba7/docs/WebSocketConnection.md#close
      connection.on('close', function (reasonCode, description) {
        console.log('[ws] close', reasonCode, description)
        app.ports.onWebsocketEvent.send({
          reasonCode,
          description,
          close: connection,
          key: request.key
        })
      })
    })
  }

  var port = process.env.PORT || 8000
  server.listen(port)
  console.log('[http] server listening at', port, '...')

  const shutdown = (signal) => {
    console.info('[http] signal received.')
    if (app.ports.onWebsocketEvent) {
      wsServer.unmount()
      console.log('[ws] server unmounted.')
    }
    server.close(() => {
      console.log('[http] server closed.')
      process.exit(signal ? 0 : 1) // not great, but there are Timers dangling and won't quit
    })
    if (app.ports.onWebsocketEvent) {
      wsServer.shutDown()
      console.log('[ws] server shutdown.')
    }
  }

  process.on('SIGTERM', shutdown)
  process.on('SIGINT', shutdown)

  if (process.argv.indexOf('--watch') > -1) {
    console.log('[watch] file changes in ./src')
    fs.watch('./src', { recursive: true }, function (eventType, filename) {
      console.log('[watch]', eventType, filename)
      setTimeout(shutdown, 100)
    })
  }
}

// regular elm initialization
const { Elm } = require('./build/Server.js')
httpServer(Elm.Server.init({
  flags: {
    jsSha: jsSha
  }
}))
