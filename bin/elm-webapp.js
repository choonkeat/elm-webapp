#!/usr/bin/env node

const path = require('path')
const fs = require('fs')
const binName = path.basename(process.argv[1])

function showUsageAndExit1 (extraMessage) {
  console.error(extraMessage || `
USAGE:

    ${binName} <type> <target_directory>

TYPE:

    While the generated "src/Server.elm" is the same, you can choose
    what kind of "src/Client.elm" to generate:

        application             generates a standard "Browser.application"

        document                generates a standard "Browser.document"

        element                 generates a standard "Browser.element"

        application-element     generates a standard "Browser.element" with
                                routing capabilities like "Browser.application"
                                but more compatible with browser extensions

    This generates a different "src/Server.elm" that comes with "CRUD"
    operations with an in-memory server state: Data is preserved on the
    Server only while the Server process is running.

        crud <TypeName>         patch the <target_directory> with the ability
                                to list, create, edit, and destroy "TypeName"
                                records

EXAMPLES:

    ${binName} application helloworld

    ${binName} document helloworld

    ${binName} element helloworld

    ${binName} application-element helloworld

    ${binName} crud Post blog
    `)
  process.exit(1)
}

function generateFromTemplate(src, dst, errcallback) {
  function logErrorIfAny (err) {
    if (!err) return
    console.error(err)
  }

  function copyFile (srcFile, dstFile) {
    console.log('Writing', dstFile, '...')
    const rd = fs.createReadStream(srcFile)
    rd.on('error', logErrorIfAny)
    const wr = fs.createWriteStream(dstFile)
    wr.on('error', logErrorIfAny)
    wr.on('close', logErrorIfAny)
    rd.pipe(wr)
  };

  function copyRecursively (src, dst, errcallback) {
    fs.readdir(src, function (err, dirnames) {
      if (err) return errcallback(err)
      fs.mkdir(dst, function () { // ignore mkdir error; pass to copyFile report
        dirnames.forEach(function (name) {
          if (name === 'package.json' || name === 'client.js') {
            // "certain files are always included, regardless of settings" 🤦
            return
          }
          const srcPath = path.join(src, name)
          const dstPath = path.join(dst, name)
          fs.stat(srcPath, function (err, dirent) {
            logErrorIfAny(err)
            if (dirent.isDirectory()) {
              copyRecursively(srcPath, dstPath, logErrorIfAny)
            } else {
              copyFile(srcPath, dstPath)
            }
          })
        })
      })
    })
  };

  return copyRecursively(src, dst, errcallback);
}

function scaffold(targetName, dstDirectory) {
  const pflag = parseInt(process.env.SCAFFOLD_PATCH_P || 2, 10) // `-p` flag of `patch`
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
    const fullpath = path.join(dstDirectory, state.filepath)
    const fileExist = !!fs.statSync(fullpath, { throwIfNoEntry: false })

    if (!state.functionLine) {
      console.log('creating', path.join(dstDirectory, state.filepath), '...')
      if (fileExist) {
        console.error(`File already exist: ${state.filepath}

  Choose a different TypeName?
  `)
        process.exit(1)
      }
      fs.mkdirSync(path.dirname(fullpath), { recursive: true })
      fs.writeFileSync(path.join(dstDirectory, state.filepath), state.body.join('\n'))
    } else {
      console.log('patching', path.join(dstDirectory, state.filepath), '...')
      const originalLines = fs.readFileSync(path.join(dstDirectory, state.filepath), { encoding: 'utf8' }).split('\n')
      const patchedLines = tryPatching(state, originalLines)
      return fs.writeFileSync(path.join(dstDirectory, state.filepath), patchedLines.join('\n'))
    }
  }

  function errorExit(str) {
    console.error(str)
    process.exit(1)
  }

  function check(state) {
    const fullpath = path.join(dstDirectory, state.filepath)
    const fileExist = !!fs.statSync(fullpath, { throwIfNoEntry: false })
    if (!state.functionLine && fileExist) {
      errorExit(`File already exist: ${state.filepath}\n\nChoose a different TypeName?\n`)
    } else if (state.functionLine && !fileExist) {
      errorExit(`File does not exist: ${state.filepath}\n\nWe can only add scaffold into directory '${dstDirectory}' if it was generated by 'elm-webapp crud ${dstDirectory}'\n`)
    }
  }

  function prefix (prefixString) {
    return function (line) {
      return prefixString + line
    }
  }

  function errorStateExit (state) {
    console.error(
      ['',
        prefix(' ')(state.functionLine),
        ...state.before.map(prefix(' ')),
        ...state.body.map(prefix('+')),
        ...state.after.map(prefix(' ')),
        ''
      ].join('\n'))
    errorExit('Patch failed!')
  }

  function noMismatch(array) {
    return array.indexOf(-1) === -1
  }

  function tryPatching (state, srcLines) {
    let fromIndex = srcLines.findIndex(function (line, index) { return line.startsWith(state.functionLine) })
    if (fromIndex === -1) errorStateExit(state) // if we cannot find the patch target function, error

    // find lines in src that matches state.before
    const beforeIndexes = state.before.map(function (line) {
      fromIndex = srcLines.indexOf(line, fromIndex)
      return fromIndex
    })
    // find lines in src that matches state.after
    const afterIndexes = state.after.map(function (line) {
      fromIndex = srcLines.indexOf(line, fromIndex)
      return fromIndex
    })
    const applyBeforePatch = function() { srcLines.splice(Math.max(...beforeIndexes) + 1, 0, ...state.body); return srcLines };
    const applyAfterPatch = function() { srcLines.splice(Math.min(...afterIndexes) - 1, 0, ...state.body); return srcLines };

    if (noMismatch(beforeIndexes) && noMismatch(afterIndexes)) {
      if (Math.min(beforeIndexes) < Math.min(afterIndexes)) return applyBeforePatch();
      return applyAfterPatch(); // if `before` matches are found too far down, we apply `after` match instead
    }
    if (noMismatch(beforeIndexes)) return applyBeforePatch();
    if (noMismatch(afterIndexes)) return applyAfterPatch();

    // cannot locate insertion point by either `before` nor `after`
    errorStateExit(state)
  }

  function escapeRegExp (string) {
    return string.replace(/[.*+\-?^${}()|[\]\\]/g, '\\$&') // $& means the whole matched string
  }

  function rename (line) {
    return line
      .replace(new RegExp(escapeRegExp('Foobar'), 'g'), targetTypeName)
      .replace(new RegExp(escapeRegExp('foobar'), 'g'), targetVarName)
  }

  let patches = []
  let state = {}

  const data = fs.readFileSync(process.env.SCAFFOLD_DIFF_FILE || path.join(__dirname, '../templates/crud.diff'), 'utf-8')
  data.split('\n').forEach(function (line) {
    if (line.startsWith('diff ')) {
      if (state.body) patches.push(state)
    } if (line.startsWith('--- ')) {
      // ignore
    } if (line.startsWith('+++ ')) {
      state = {
        filepath: rename(filepathFrom(line))
      }
    } else if (line.startsWith('@@ ')) {
      if (state.body) patches.push(state)
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
  if (state.body) patches.push(state)

  patches.forEach(check)
  patches.forEach(apply)
}

function showDone(dstDirectory) {
  console.log(`
  Done! Now execute:

      1. cd ${dstDirectory}
      2. make install
      3. make
  `)
}

const clientType = process.argv[2]

if (typeof clientType === 'undefined') {
  showUsageAndExit1()

} else if (clientType.startsWith('crud')) {
  const targetName = process.argv[3]
  const dstDirectory = process.argv[4]
  if (typeof dstDirectory === 'undefined') {
    showUsageAndExit1(`
Sorry! You are missing some arguments in your commandline:

    ${binName} crud <TypeName> <target_directory>

For example:

    ${binName} crud Article mynewspaper
    `);
  }
  if (! targetName.match(/^[A-Z][a-z]*$/s)) {
    showUsageAndExit1("\nSorry! `" + targetName + "` must be a valid _name_ for an Elm custom type.\n");
  }
  fs.stat(dstDirectory, function(err, stat) {
    if (!err && stat.isDirectory()) {
      return scaffold(targetName, dstDirectory) // existing directory, patch into it
    }

    // otherwise, generate crud THEN patch into it
    generateFromTemplate(path.join(path.dirname(__dirname), 'templates', clientType), dstDirectory, showUsageAndExit1)
    process.on('exit', function (code) {
      if (code === 0) {
        scaffold(targetName, dstDirectory)
        showDone(dstDirectory)
      }
    })
  })

} else {
  const dstDirectory = process.argv[3]
  if (typeof dstDirectory === 'undefined') showUsageAndExit1();

  process.on('exit', function (code) {
    if (code === 0) showDone(dstDirectory)
  })
  generateFromTemplate(path.join(path.dirname(__dirname), 'templates', clientType), dstDirectory, showUsageAndExit1)
}
