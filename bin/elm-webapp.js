#!/usr/bin/env node

const path = require('path')
const fs = require('fs')

const dirName = path.dirname(__dirname)
const binName = path.basename(process.argv[1])
const clientType = process.argv[2]
const dstName = process.argv[3]

function logErrorIfAny(err) {
    if (!err) return;
    console.error(err)
}

function copy_file(srcFile, dstFile) {
    console.log("copy", srcFile, dstFile, "...")
    var rd = fs.createReadStream(srcFile);
    rd.on("error", logErrorIfAny);
    var wr = fs.createWriteStream(dstFile);
    wr.on("error", logErrorIfAny);
    wr.on("close", logErrorIfAny);
    rd.pipe(wr);
};

function copy_recursively (src, dst, callback) {
    fs.readdir(src, function (err, dirnames) {
        if (err) return callback(err)
        fs.mkdir(dst, function() { // ignore mkdir error; pass to copy_file report
            dirnames.forEach(function(name) {
                if (name === "package.json") return; // "certain files are always included, regardless of settings" 🤦
                const srcPath = path.join(src, name)
                const dstPath = path.join(dst, name)
                fs.stat(srcPath, function(err, dirent) {
                    if (dirent.isDirectory()) {
                        copy_recursively(srcPath, dstPath, logErrorIfAny);
                    } else {
                        copy_file(srcPath, dstPath)
                    }
                })
            })
        })
    })
};

function showUsage() {
    console.error(`

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

        crud                    generates a standard "Browser.application"
                                with the ability to list, create, edit, and
                                destroy "Foobar" records

EXAMPLE:

    ${binName} application helloworld

    `);
    process.exit(1)
}

if (typeof dirName === 'undefined' || typeof dstName === 'undefined') {
    showUsage()
} else {
    copy_recursively(path.join(dirName, 'templates', clientType), dstName, showUsage)
}
