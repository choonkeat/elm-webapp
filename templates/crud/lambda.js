function lambdaHttpServer ({ app }) {
  const fs = require('fs')
  const mime = require('mime')
  const path = require('path')
  const zlib = require('zlib')
  const crypto = require('crypto')

  function toQueryString (kvpairs) {
    const result = []
    for (const k in kvpairs) {
      const values = kvpairs[k]
      for (const i in values) {
        result.push(encodeURIComponent(k) + '=' + encodeURIComponent(values[i]))
      }
    }
    if (result.length === 0) {
      return ''
    }
    return '?' + result.join('&')
  }

  function toLowerCaseKeys (kvpairs) {
    const result = {}
    for (const k in kvpairs) {
      result[k.toLowerCase()] = kvpairs[k]
    }
    return result
  }

  // when Elm tries to write http response
  // we find the {req,res} pair according to `requestid`, and res.write...
  app.ports.onHttpResponse.subscribe(({ statusCode, body, headers, request }) => {
    request.callback(null, {
      body: body,
      statusCode: statusCode,
      headers: {
        ...headers,
        'Content-Length': '' + Buffer.byteLength(body)
      }
    })
  })

  return function (event, ctx, callback) {
    ctx.callbackWaitsForEmptyEventLoop = false

    event.headers = event.headers || {} // blank when `lambda > test` or other events

    // https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-develop-integrations-lambda.html
    const requestPath = (event.path || event.rawPath || (event.requestContext && event.requestContext.http && event.requestContext.http.path))
    const queryString = (event.multiValueQueryStringParameters ? toQueryString(event.multiValueQueryStringParameters) : event.rawQueryString)
    const url =
      (event.headers['CloudFront-Forwarded-Proto'] || 'https') + '://' +
      (event.headers.Host || (event.requestContext && event.requestContext.domainName)) +
      requestPath + (queryString ? ('?' + queryString) : '')

    try {
      // try serving static file
      let staticContent = fs.readFileSync('./public/assets/' + path.basename(requestPath), { encoding: 'utf8', flag: 'r' })
      const staticContentLength = staticContent.length
      const etag = crypto.createHmac('SHA256', requestPath).update(staticContent).digest('base64')

      callback(null, {
        statusCode: 200,
        headers: {
          ETag: JSON.stringify(etag),
          'Content-Type': mime.types[path.extname(requestPath).substring(1)] || mime.default_type,
          'Content-Length': '' + staticContentLength
        },
        body: staticContent.toString('base64')
      })
    } catch (e) {
      // not static file, send to elm
      const contentType = event.headers['Content-Type'] || ''
      const encoding = (contentType.match(/; charset=(\S+)/) || ['', 'utf8'])[1] // charset or default to `utf8`
      const bodyString = Buffer.from(event.body || '', event.isBase64Encoded ? 'base64' : null).toString(encoding)
      event.headers['x-request-id'] = ctx.awsRequestId

      app.ports.onHttpRequest.send({
        ctx: ctx,
        callback: callback,
        method: event.requestContext.httpMethod,
        url: url,
        path: requestPath,
        body: bodyString,
        headers: toLowerCaseKeys(event.headers)
      })
    }
  }
}

exports.lambdaHttpServer = lambdaHttpServer
