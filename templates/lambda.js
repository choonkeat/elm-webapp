function lambdaHttpServer ({ app }) {
  const path = require('path')

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
    const url =
      (event.headers['CloudFront-Forwarded-Proto'] || 'https') + '://' +
      (event.headers.Host || (event.requestContext && event.requestContext.domainName)) + event.path +
      toQueryString(event.multiValueQueryStringParameters || {})

    const contentType = event.headers['Content-Type'] || ''
    const encoding = (contentType.match(/; charset=(\S+)/) || ['', 'utf8'])[1] // charset or default to `utf8`
    const bodyString = Buffer.from(event.body || '', event.isBase64Encoded ? 'base64' : null).toString(encoding)
    event.headers['x-request-id'] = ctx.awsRequestId

    app.ports.onHttpRequest.send({
      ctx: ctx,
      callback: callback,
      method: event.requestContext.httpMethod,
      url: url,
      path: event.path,
      body: bodyString,
      headers: toLowerCaseKeys(event.headers)
    })
  }
}

exports.lambdaHttpServer = lambdaHttpServer
