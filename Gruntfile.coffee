module.exports = (grunt) ->
  grunt.util.linefeed = '\n'

  importHTML = (filename) ->
    "(innerHTML: #{JSON.stringify grunt.file.read("src/General/html/#{filename}.html").replace(/^ +| +$</gm, '').replace(/\r?\n/g, '')})"

  html = (template) ->
    parts = template.split /([\$&@]){([^}`]*)}/
    parts2 = []
    checkText = ''
    for part, i in parts
      switch i % 3
        when 0
          parts2.push JSON.stringify part unless part is ''
          checkText += part
        when 1
          if /<[^>]*$/.test(checkText) and not (part is '$' and /\=['"][^"'<>]*$/.test checkText)
            throw new Error "Illegal insertion into HTML template: #{template}"
          parts2.push switch part
            when '$' then "E(`#{parts[i+1]}`)"
            when '&' then "`#{parts[i+1]}`.innerHTML"
            when '@' then "`#{parts[i+1]}`.map((x) -> x.innerHTML).join('')"
    unless /^(<\w+( [\w-]+(='[^"'<>]*'|="[^"'<>]*")?)*>|<\/\w+>|[^"'<>]*)*$/.test checkText
      throw new Error "HTML template is ill-formed: #{template}"
    output = if parts2.length is 0 then '""' else parts2.join ' + '
    "(innerHTML: #{output})"

  assert = (statement, objs...) ->
    return '' unless grunt.config('pkg').tests_enabled
    "throw new Error 'Assertion failed: ' + `#{JSON.stringify statement}` unless #{statement}"

  # Project configuration.
  grunt.initConfig
    pkg: grunt.file.readJSON 'package.json'

    concat:
      options: process: Object.create(null, data:
        get: ->
          pkg = grunt.config 'pkg'
          pkg.importHTML = importHTML
          pkg.html = html
          pkg.assert = assert
          pkg.tests_enabled or= false
          pkg
        enumerable: true
      )
      coffee:
        src: [
          'src/General/Cheats.coffee'
          'src/General/Config.coffee'
          'src/General/Globals.coffee'
          'src/General/lib/*.coffee'
          'src/General/Header.coffee'
          'src/General/Index.coffee'
          'src/General/Build.coffee'
          'src/General/Get.coffee'
          'src/General/UI.coffee'
          'src/General/Notice.coffee'
          'src/General/CrossOrigin.coffee'
          'src/General/BuildTest.coffee'
          'src/Filtering/**/*.coffee'
          'src/Quotelinks/**/*.coffee'
          'src/Posting/QR.coffee'
          'src/Posting/Captcha.coffee'
          'src/Posting/**/*.coffee'
          'src/Images/**/*.coffee'
          'src/Linkification/**/*.coffee'
          'src/Menu/**/*.coffee'
          'src/Monitoring/**/*.coffee'
          'src/Archive/**/*.coffee'
          'src/Miscellaneous/**/*.coffee'
          'src/General/Settings.coffee'
          'src/General/Main.coffee'
        ]
        dest: 'tmp-<%= pkg.type %>/script.coffee'
      meta:
        files:
          'LICENSE':   'src/General/meta/banner.js'
      crx:
        files:
          'testbuilds/updates<%= pkg.meta.suffix[pkg.channel] %>.xml': 'src/General/meta/updates.xml'
          'testbuilds/crx<%= pkg.meta.suffix[pkg.channel] %>/manifest.json': 'src/General/meta/manifest.json'
          'testbuilds/crx<%= pkg.meta.suffix[pkg.channel] %>/script.js': [
            'src/General/meta/botproc.js'
            'src/General/meta/banner.js'
            'src/General/meta/usestrict.js'
            'tmp-<%= pkg.type %>/script.js'
          ]
          'testbuilds/crx<%= pkg.meta.suffix[pkg.channel] %>/eventPage.js': 'tmp-<%= pkg.type %>/eventPage.js'
      userscript:
        files:
          'testbuilds/<%= pkg.name %><%= pkg.meta.suffix[pkg.channel] %>.meta.js': 'src/General/meta/metadata.js'
          'testbuilds/<%= pkg.name %><%= pkg.meta.suffix[pkg.channel] %>.user.js': [
            'src/General/meta/botproc.js'
            'src/General/meta/metadata.js'
            'src/General/meta/banner.js'
            'src/General/meta/usestrict.js'
            'tmp-<%= pkg.type %>/script.js'
          ]

    copy:
      crx:
        src:  'src/General/img/*.png'
        dest: 'testbuilds/crx<%= pkg.meta.suffix[pkg.channel] %>/'
        expand:  true
        flatten: true
      builds:
        cwd: 'testbuilds/'
        src: '*'
        dest: 'builds/'
        expand: true
        filter: (src) ->
          pkg = grunt.config 'pkg'
          grunt.file.isFile(src) and !grunt.file.isMatch(src, "testbuilds/#{pkg.name}#{pkg.meta.suffix.dev}.user.js")

    coffee:
      script:
        src:  'tmp-<%= pkg.type %>/script.coffee'
        dest: 'tmp-<%= pkg.type %>/script.js'
      eventPage:
        src:  'src/General/eventPage/eventPage.coffee'
        dest: 'tmp-<%= pkg.type %>/eventPage.js'

    concurrent:
      build: [
        'build-crx'
        'build-userscript'
      ]

    shell:
      options:
        stdout: true
        stderr: true
        failOnError: true
      checkout:
        command: 'git checkout <%= pkg.meta.mainBranch %>'
      commit:
        command: """
          git commit -am "Release <%= pkg.meta.name %> v<%= pkg.meta.version %>."
          git tag -a <%= pkg.meta.version %> -m "<%= pkg.meta.name %> v<%= pkg.meta.version %>."
        """.split('\n').join('&&')
      beta:
        command: """
          git tag -af beta -m "<%= pkg.meta.name %> v<%= pkg.meta.version %>."
          git checkout gh-pages
          git checkout beta "builds/*<%= pkg.meta.suffix.beta %>.*"
          git commit -am "Move <%= pkg.meta.name %> v<%= pkg.meta.version %> to beta channel."
          git checkout -
        """.split('\n').join('&&')
      stable:
        command: """
          git tag -af stable -m "<%= pkg.meta.name %> v<%= pkg.meta.version %>."
          git checkout -b tmp
          git merge --no-commit -s ours gh-pages
          git checkout gh-pages "builds/*<%= pkg.meta.suffix.beta %>.*" README.md template.jst index.html img
          git commit -am "Move <%= pkg.meta.name %> v<%= pkg.meta.version %> to stable channel."
          git checkout gh-pages
          git merge --ff-only tmp
          git branch -d tmp
          git checkout @{-2}
        """.split('\n').join('&&')
      web:
        command: """
          git commit -am "Build web page."
          git checkout gh-pages
          git checkout - README.md template.jst index.html img
          git commit -am "Update web page."
          git checkout -
        """.split('\n').join('&&')
      push:
        command: 'git push origin --tags -f && git push origin --all'

    watch:
      options:
        interrupt: true
      all:
        files: [
          'Gruntfile.coffee'
          'package.json'
          'src/**/*'
        ]
        tasks: 'build'

    crx:
      prod:
        src: 'testbuilds/crx<%= pkg.meta.suffix[pkg.channel] %>/'
        dest: 'testbuilds/<%= pkg.name %><%= pkg.meta.suffix[pkg.channel] %>.crx'
        privateKey: '../<%= pkg.name %>.pem'

    compress:
      crx:
        options:
          archive: 'testbuilds/<%= pkg.name %>.zip'
          level: 9
          pretty: true
        expand:  true
        flatten: true
        src: 'testbuilds/crx<%= pkg.meta.suffix.noupdate %>/*'
        dest: '/'

    clean:
      builds: 'builds'
      testbuilds: 'testbuilds'
      tmpcrx: ['tmp-crx', 'testbuilds/updates<%= pkg.meta.suffix.noupdate %>.xml']
      tmpuserscript: [
        'tmp-userscript',
        'testbuilds/<%= pkg.name %><%= pkg.meta.suffix.noupdate %>.meta.js',
        'testbuilds/<%= pkg.name %><%= pkg.meta.suffix.dev %>.meta.js'
      ]

    markdown:
      web:
        src: 'README.md'
        dest: 'index.html'
      options:
        template: 'template.jst'

    jshint:
      options:
        undef:   true
        eqnull:  true
        expr:    true
        shadow:  true
        sub:     true
        scripturl: true
        browser: true
        devel:   true
        nonstandard: true
        # XXX Temporarily suppress lots of existing warnings until we fix them.
        '-W018': true
        '-W053': true
        '-W084': true
        '-W058': true
        '-W083': true
        '-W093': true
        globals:
          Notification: true
          webkitNotifications: true
          HTMLDocument: true
          MediaError:   true
          GM_getValue:  true
          GM_setValue:  true
          GM_deleteValue: true
          GM_listValues: true
          GM_openInTab: true
          GM_info:      true
          GM_xmlhttpRequest: true
          cloneInto:    true
          chrome:       true
      script: 'tmp-<%= pkg.type %>/*.js'

  require('load-grunt-tasks') grunt

  grunt.registerTask 'default', [
    'build'
  ]

  grunt.registerTask 'set-build', 'Set the build type variable', (type) ->
    pkg = grunt.config 'pkg'
    pkg.type = type
    grunt.config 'pkg', pkg
    grunt.log.ok 'pkg.type = %s', type

  grunt.registerTask 'set-channel', 'Set the update channel', (channel) ->
    pkg = grunt.config 'pkg'
    pkg.channel = channel
    grunt.config 'pkg', pkg

  grunt.registerTask 'enable-tests', 'Include testing code', () ->
    pkg = grunt.config 'pkg'
    pkg.tests_enabled = true
    grunt.config 'pkg', pkg

  grunt.registerTask 'build', [
    'concurrent:build'
  ]

  grunt.registerTask 'build-crx-channel', [
    'concat:crx'
    'copy:crx'
  ]

  grunt.registerTask 'build-crx', [
    'set-build:crx'
    'concat:coffee'
    'coffee:script'
    'coffee:eventPage'
    'jshint:script'
    'set-channel:stable'
    'build-crx-channel'
    'set-channel:beta'
    'build-crx-channel'
    'set-channel:noupdate'
    'build-crx-channel'
    'compress:crx'
    'clean:tmpcrx'
  ]

  grunt.registerTask 'pack', [
    'set-channel:stable'
    'crx:prod'
    'set-channel:beta'
    'crx:prod'
    'set-channel:noupdate'
    'crx:prod'
  ]

  grunt.registerTask 'build-userscript', [
    'set-build:userscript'
    'concat:coffee'
    'coffee:script'
    'jshint:script'
    'set-channel:stable'
    'concat:userscript'
    'set-channel:beta'
    'concat:userscript'
    'set-channel:noupdate'
    'concat:userscript'
    'set-channel:dev'
    'concat:userscript'
    'clean:tmpuserscript'
  ]

  grunt.registerTask 'build-tests', [
    'enable-tests'
    'build-userscript'
    'build-crx'
  ]

  grunt.registerTask 'tag', 'Tag a new version', (version) ->
    grunt.task.run [
      "setversion:#{version}"
      'updcl'
      'build'
      'pack'
      'concat:meta'
      'copy:builds'
      'shell:commit'
    ]

  grunt.registerTask 'beta', [
    'shell:beta'
  ]

  grunt.registerTask 'stable', [
    'shell:stable'
  ]

  grunt.registerTask 'web', [
    'markdown:web'
    'shell:web'
  ]

  grunt.registerTask 'push', [
    'shell:push'
  ]

  grunt.registerTask 'setversion', 'Set the version number', (version) ->
    pkg = grunt.file.readJSON 'package.json'
    oldversion = pkg.meta.version
    pkg.meta.version = version
    grunt.config 'pkg', pkg
    grunt.file.write 'package.json', JSON.stringify(pkg, null, 2)
    grunt.log.ok "Version updated from v#{oldversion} to v#{version}."

  grunt.registerTask 'updcl', 'Update the changelog', ->
    {meta, name} = grunt.config('pkg')
    {version, oldVersions, suffix} = meta

    branch       = version.replace /\.\d+$/, ''
    headerLevel  = branch.replace(/(\.0)*$/, '').split('.').length
    headerPrefix = new Array(headerLevel + 1).join '#'
    separator    = "#{headerPrefix} v#{branch}"

    today    = grunt.template.today 'yyyy-mm-dd'
    filename = "/builds/#{name}#{suffix.noupdate}"
    ffLink   = "#{oldVersions}#{version}#{filename}.user.js"
    crLink   = "#{oldVersions}#{version}#{filename}.crx"
    line     = "**v#{version}** *(#{today})* - [[Firefox](#{ffLink} \"Firefox version\")] [[Chromium](#{crLink} \"Chromium version\")]"

    changelog = grunt.file.read 'CHANGELOG.md'

    breakPos = changelog.indexOf(separator)
    throw new Error 'Separator not found.' if breakPos is -1
    breakPos += separator.length

    grunt.file.write 'CHANGELOG.md', "#{changelog[...breakPos]}\n\n#{line}#{changelog[breakPos..]}"
    grunt.log.ok "Changelog updated for v#{version}."
