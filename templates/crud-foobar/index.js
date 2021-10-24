global.XMLHttpRequest = require('xhr2')

//
const fs = require('fs')
const crypto = require('crypto')
const hash = crypto.createHash('sha256')
const jsData = fs.readFileSync('public/assets/client.js', { encoding: 'utf8' })
hash.update(jsData)
const jsSha = hash.digest('hex')
//

// regular elm initialization
const { Elm } = require('./build/Server.js')
var app = Elm.Server.init({
  flags: {
    assetsHost: process.env.ASSETS_HOST || '',
    jsSha: jsSha
  }
})

function loggerWith (logger, ...context) {
  return function (...messages) {
    logger(context, ...messages)
    /* context is wrapped in [ square brackets ] */
  }
}
const log = loggerWith(console.log, 'js')
const httpServer = (process.env.LAMBDA
  ? require('./lambda.js').lambdaHttpServer
  : require('./node.js').nodeHttpServer
)
log('httpServer', httpServer)
exports.handler = httpServer({
  log: loggerWith(log, 'http'),
  app: app
})
