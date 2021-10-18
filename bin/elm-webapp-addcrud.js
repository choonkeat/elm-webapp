const fs = require('fs')
const path = require('path')
const data = fs.readFileSync(path.join(__dirname, '../templates/crud.diff'), 'utf-8')
const pflag = 2 // patch -p 2
const binName = path.basename(process.argv[1])
const targetName = process.argv[2]
if (!targetName) {
  console.error(`

Usage: ${binName} <TypeName>

    `)
  process.exit(1)
}
const targetTypeName = targetName.substring(0, 1).toUpperCase() + targetName.substring(1)
const targetVarName = targetName.substring(0, 1).toLowerCase() + targetName.substring(1)

// "+++ some/path/file/name.ext\tyyyy-mm-dd"
function filepathFrom (line) {
  const parts = line.split('\t')[0].substring(4).split(path.sep)
  for (let i = pflag; i > 0; i--) parts.shift()
  return parts.join(path.sep)
}

// @@ ..... @@ fname arg =
function functionLineFrom (line) {
  if (line.endsWith(' @@')) return
  return line.substring(line.lastIndexOf(' @@ ') + 4)
}

//
// state= {
//   filepath: 'src/Server.elm',
//   functionLine: 'updateFromClient : Protocol.RequestConte',
//   before: [
//     'updateFromClient ctx now clientMsg serverState =',
//     '    case clientMsg of'
//   ],
//   body: [
//     '        Protocol.MsgFromFoobar m ->',
//     '            Server.FoobarAPI.updateFromClient ctx now m serverState',
//     ''
//   ],
//   after: [
//     '        Protocol.ManyMsgFromClient msglist ->',
//     '            -- Handling a batched list of `MsgFromClient`',
//     '',
//     ''
//   ]
// }
//
function apply (state) {
  if (!state.functionLine) {
    console.log('creating', state.filepath, '...')
    fs.mkdirSync(path.dirname(state.filepath), { recursive: true })
    return fs.writeFileSync(state.filepath, state.body.join('\n'))
  } else {
    console.log('patching', state.filepath, '...')
    const originalLines = fs.readFileSync(state.filepath, { encoding: 'utf8' }).split('\n')
    const patchedLines = tryPatching(state, originalLines)
    return fs.writeFileSync(state.filepath, patchedLines.join('\n'))
  }
}

function prefix (prefixString) {
  return function (line) {
    return prefixString + line
  }
}

function raiseError (state) {
  console.error(
    ['',
      prefix(' ')(state.functionLine),
      ...state.before.map(prefix(' ')),
      ...state.body.map(prefix('+')),
      ...state.after.map(prefix(' ')),
      ''
    ].join('\n'))
  console.error('Patch failed!')
  process.exit(1)
}

function tryPatching (state, srcLines) {
  let fromIndex = srcLines.findIndex(function (line, index) { return line.startsWith(state.functionLine) })
  if (fromIndex === -1) raiseError(state)

  const beforeIndexes = state.before.map(function (line) {
    fromIndex = srcLines.indexOf(line, fromIndex)
    return fromIndex
  })
  if (beforeIndexes.indexOf(-1) === -1) {
    srcLines.splice(Math.max(...beforeIndexes) + 1, 0, ...state.body)
    return srcLines
  }

  const afterIndexes = state.after.map(function (line) {
    fromIndex = srcLines.indexOf(line, fromIndex)
    return fromIndex
  })
  if (afterIndexes.indexOf(-1) === -1) {
    srcLines.splice(Math.min(...beforeIndexes) - 1, 0, ...state.body)
    return srcLines
  }

  // cannot locate insertion point by either before nor after
  raiseError(state)
}

function escapeRegExp (string) {
  return string.replace(/[.*+\-?^${}()|[\]\\]/g, '\\$&') // $& means the whole matched string
}

function rename (line) {
  return line
    .replace(new RegExp(escapeRegExp('Foobar'), 'g'), targetTypeName)
    .replace(new RegExp(escapeRegExp('foobar'), 'g'), targetVarName)
}

let state = {}
data.split('\n').forEach(function (line) {
  if (line.startsWith('diff ')) {
    if (state.body) apply(state)
  } if (line.startsWith('--- ')) {
    // ignore
  } if (line.startsWith('+++ ')) {
    state = {
      filepath: rename(filepathFrom(line))
    }
  } else if (line.startsWith('@@ ')) {
    if (state.body) apply(state)
    state = {
      filepath: rename(state.filepath),
      functionLine: functionLineFrom(line),
      before: [],
      body: [],
      after: []
    }
  } else if (line.startsWith('+')) {
    state.body.push(rename(line.substring(1)))
  } else if (state.body && state.body.length === 0) {
    state.before.push(line.substring(1))
  } else if (state.body) {
    state.after.push(line.substring(1))
  }
})
if (state.body) apply(state)
