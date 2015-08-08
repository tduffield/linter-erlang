{BufferedProcess, CompositeDisposable} = require 'atom'
path = require 'path'
helpers = require('atom-linter')

module.exports =
  config:
    executablePath:
      type: 'string'
      title: 'Erlc Executable Path'
      default: '/usr/local/bin/erlc'
    includeDirs:
      type: 'string'
      title: 'Include dirs'
      description: 'Path to include dirs. Seperated by space.'
      default: './include'
    paPaths:
      type: 'string'
      title: 'pa paths'
      default: ""
      description: "Paths seperated by space"
  activate: ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.config.observe 'linter-erlang.executablePath',
      (executablePath) =>
        @executablePath = executablePath
    @subscriptions.add atom.config.observe 'linter-erlang.includeDirs',
      (includeDirs) =>
        @includeDirs = includeDirs
    @subscriptions.add atom.config.observe 'linter-erlang.paPaths',
      (paPaths) =>
        @paPaths = paPaths
  deactivate: ->
    @subscriptions.dispose()
  provideLinter: ->
    provider =
      grammarScopes: ['source.erlang']
      scope: 'file' # or 'project'
      lintOnFly: false # must be false for scope: 'project'
      lint: (textEditor) =>
        return new Promise (resolve, reject) =>
          filePath = textEditor.getPath()
          compile_result = ""
          foobar = ["-Wall"]
          project_path = atom.project.getPaths()
          foobar.push filePath
          foobar.push "-I", dir.trim() for dir in @includeDirs.split(" ")
          foobar.push "-pa", pa.trim() for pa in @paPaths.split(" ") unless @paPaths == ""
          ## This fun will parse the row and split stuff nicely
          error_stack = []
          parse_row = (row) ->
            row_splittreedA = row.slice(0, row.indexOf(":"))
            re = /[\w\/.]+:(\d+):(.+)/
            re_result = re.exec(row)
            if re_result[2].trim().startsWith("Warning")
              error_type = "Warning"
            else
              error_type = "Error"
            linenr = parseInt(re_result[1], 10)
            error_stack.push
              type: error_type
              text: re_result[2].trim()
              filePath: filePath
              range: helpers.rangeFromLineNumber(textEditor, linenr - 1)
          process = new BufferedProcess
            command: @executablePath
            args: foobar
            options:
              cwd: project_path[0] # Should use better folder perhaps
            stdout: (data) ->
              compile_result += data
            exit: (code) ->
              errors = compile_result.split("\n")
              errors.pop()
              parse_row error for error in errors
              resolve error_stack
          process.onWillThrowError ({error,handle}) ->
            atom.notifications.addError "Failed to run #{@executablePath}",
              detail: "#{error.message}"
              dismissable: true
            handle()
            resolve []