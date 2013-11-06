"use strict"
exec = require("child_process").exec
module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON("package.json")
    dirs:
      components: 'bower_components/'

    coffee:
      compile:
        files:
          "src/main.js": ["src/app/apps/*.coffee"] # compile and concat into single file

    uglify:
      options:
        banner: "/*! <%= pkg.name %> <%= grunt.template.today(\"dd-mm-yyyy\") %> */\n"

      dist:
        files:
          "src/main.min.js": ["<%= coffee.compile.files[0] %>"]

    qunit:
      all: ['./src/tests/*.html']

    jshint:
      files: ["gruntfile.js", "src/*.js", "test/**/*.js"]
      options:
        # options here to override JSHint defaults
        globals:
          jQuery: true
          console: true
          module: true
          document: true

    concat:
      options:
        separator: ';'
      dist:
        src:  ['src/libs/*.js']
        dest: 'src/libs.js'
      bundle:
        src: [
          "<%= dirs.components %>jquery/jquery.js",
          "<%= dirs.components %>underscore/underscore.js",
          "<%= dirs.components %>highcharts/highcharts.js",
          "<%= dirs.components %>bootstrap/dist/js/bootstrap.js",
          "<%= dirs.components %>angular/angular.min.js",
          "<%= dirs.components %>highcharts-ng/src/directives/highcharts-ng.js"
        ]
        dest: 'src/bundle.js'

    shell:
      chmod:
        command: "chmod -v +x build/v<%= pkg.version %>/<%= grunt.template.today('yyyy-mm-dd') %>/Forge.app/Contents/MacOS/node-webkit build/v<%= pkg.version %>/<%= grunt.template.today('yyyy-mm-dd') %>/Forge.app//Contents/Frameworks/node-webkit\\ Helper.app/Contents/MacOS/node-webkit\\ Helper"
        options:
          stdout: true
      scratch:
        command: "rm *.nw && zip -r ${PWD##*/}.nw * -n .nw -x ./node_modules/**\\*" 
        options:
          stdout: true
      build:
        command: "zip -r ${PWD##*/}.nw * -n .nw -x ./node_modules/**\\*" 
        options:
          stdout: true
      run:
        command: 'open build/v<%= pkg.version %>/<%= grunt.template.today("yyyy-mm-dd") %>/Forge.app'
        options:
          stdout: true
          stderr: true

    copy:
      build:
        files:
          [
            expand: true
            src: ['src/index.html', 'src/*.js','src/styles/**','src/img/**' ,'package.json']
            dest: 'build/v<%= pkg.version %>/<%= grunt.template.today("yyyy-mm-dd") %>/Forge.app/Contents/Resources/app.nw/'
          ]
      addNodeWebkit:
        files:
          [
            expand: true
            cwd: 'build/osx/node-webkit.app/'
            src: ['**']
            dest: 'build/v<%= pkg.version %>/<%= grunt.template.today("yyyy-mm-dd") %>/Forge.app/'
          ]
      copyIcon:
        files:
          [
            expand: true
            cwd: 'src/img/'
            src: 'nw.icns'
            dest: 'build/v<%= pkg.version %>/<%= grunt.template.today("yyyy-mm-dd") %>/Forge.app/Contents/Resources/'
          ]
      copyBootstrapCss:
        files:
          [
            expand: true
            cwd: '<%= dirs.components %>bootstrap/dist/css/'
            src: 'bootstrap.css'
            dest: 'src/styles'
          ]

    growl:
      compiled:
        message: "Finished Compiling"
        title: "Finished Compiling"
      tests:
        message: "Tests Passed"
        title: "Tests Passed"

    macreload:
      chrome:
        browser: 'chrome'
        editor: 'sublime'

    watch:
      files: ["src/**/*.coffee"]
      tasks: ["compile"]

  grunt.loadNpmTasks "grunt-docco-multi"
  grunt.loadNpmTasks "grunt-growl" #requires sudo gem install terminal-notifier
  grunt.loadNpmTasks "grunt-contrib"
  grunt.loadNpmTasks "grunt-shell"
  grunt.loadNpmTasks "grunt-bower-concat"
  grunt.loadNpmTasks "grunt-macreload"
  grunt.registerTask "test", ["qunit"]
  grunt.registerTask "default", ["jshint", "qunit", "coffee", "handlebars", "uglify"]
  grunt.registerTask "compile", ["coffee", "concat", "copy:copyBootstrapCss", "growl:compiled"]
  grunt.registerTask "scratch", ["compile", "shell:scratch"]
  grunt.registerTask "build", ["compile", "copy:build","copy:addNodeWebkit","copy:copyIcon","shell:chmod"]
  grunt.registerTask "run", ["shell:run"]
  grunt.registerTask "brun", ["build","run"]