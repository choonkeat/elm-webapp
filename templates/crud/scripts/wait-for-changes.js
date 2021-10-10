#!/usr/bin/env node

const fs = require('fs')
const target = process.argv.reverse()[0]
fs.watch(target, { recursive: true }, function (eventType, filename) {
  console.log('[wait]', eventType, filename)
  this.close()
})
console.log('[wait] until file changes in', target)
