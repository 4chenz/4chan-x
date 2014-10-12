ThreadWatcher =
  init: ->
    return if !Conf['Thread Watcher']

    @shortcut = sc = $.el 'a',
      id:   'watcher-link'
      title: 'Thread Watcher'
      href: 'javascript:;'
      className: 'disabled fa fa-eye'
    $.extend sc, <%= html('<span>Watcher</span>') %>

    @db     = new DataBoard 'watchedThreads', @refresh, true
    @dialog = UI.dialog 'thread-watcher', 'top: 50px; left: 0px;', <%= importHTML('Monitoring/ThreadWatcher') %>
    @status = $ '#watcher-status', @dialog
    @list   = @dialog.lastElementChild
    @refreshButton = $ '.move > .refresh', @dialog

    @unreaddb = Unread.db or new DataBoard 'lastReadPosts'

    $.on d, 'QRPostSuccessful',   @cb.post
    $.on sc, 'click', @toggleWatcher
    $.on @refreshButton, 'click', @fetchAllStatus
    $.on $('.move > .close', @dialog), 'click', @toggleWatcher

    $.on d, '4chanXInitFinished', @ready
    switch g.VIEW
      when 'index'
        $.on d, 'IndexRefresh', @cb.onIndexRefresh
      when 'thread'
        $.on d, 'ThreadUpdate', @cb.onThreadRefresh

    if Conf['Toggleable Thread Watcher']
      Header.addShortcut sc
      $.addClass doc, 'fixed-watcher'

    now = Date.now()
    if (@db.data.lastChecked or 0) < now - 2 * $.HOUR
      @db.data.lastChecked = now
      ThreadWatcher.fetchAllStatus()
      @db.save()

    Thread.callbacks.push
      name: 'Thread Watcher'
      cb:   @node

  node: ->
    toggler = $.el 'img',
      className: 'watch-thread-link'
    $.on toggler, 'click', ThreadWatcher.cb.toggle
    $.before $('input', @OP.nodes.post), toggler

  ready: ->
    $.off d, '4chanXInitFinished', ThreadWatcher.ready
    return unless Main.isThisPageLegit()
    ThreadWatcher.refresh()
    $.add d.body, ThreadWatcher.dialog

    if Conf['Toggleable Thread Watcher']
      ThreadWatcher.dialog.hidden = true

    return unless Conf['Auto Watch']
    $.get 'AutoWatch', 0, ({AutoWatch}) ->
      return unless thread = g.BOARD.threads[AutoWatch]
      ThreadWatcher.add thread
      $.delete 'AutoWatch'

  toggleWatcher: ->
    $.toggleClass ThreadWatcher.shortcut, 'disabled'
    ThreadWatcher.dialog.hidden = !ThreadWatcher.dialog.hidden

  cb:
    openAll: ->
      return if $.hasClass @, 'disabled'
      for a in $$ 'a[title]', ThreadWatcher.list
        $.open a.href
      $.event 'CloseMenu'
    pruneDeads: ->
      return if $.hasClass @, 'disabled'
      for {boardID, threadID, data} in ThreadWatcher.getAll() when data.isDead
        delete ThreadWatcher.db.data.boards[boardID][threadID]
        ThreadWatcher.db.deleteIfEmpty {boardID}
      ThreadWatcher.db.save()
      ThreadWatcher.refresh()
      $.event 'CloseMenu'
    toggle: ->
      ThreadWatcher.toggle Get.postFromNode(@).thread
    rm: ->
      [boardID, threadID] = @parentNode.dataset.fullID.split '.'
      ThreadWatcher.rm boardID, +threadID
    post: (e) ->
      {boardID, threadID, postID} = e.detail
      if postID is threadID
        if Conf['Auto Watch']
          $.set 'AutoWatch', threadID
      else if Conf['Auto Watch Reply']
        ThreadWatcher.add g.threads[boardID + '.' + threadID]
    onIndexRefresh: ->
      {db}    = ThreadWatcher
      boardID = g.BOARD.ID
      for threadID, data of db.data.boards[boardID] when not data.isDead and threadID not of g.BOARD.threads
        if Conf['Auto Prune']
          ThreadWatcher.db.delete {boardID, threadID}
        else
          data.isDead = true
          ThreadWatcher.db.set {boardID, threadID, val: data}
      ThreadWatcher.refresh()
    onThreadRefresh: (e) ->
      thread = g.threads[e.detail.threadID]
      return unless e.detail[404] and ThreadWatcher.db.get {boardID: thread.board.ID, threadID: thread.ID}
      # Update dead status.
      ThreadWatcher.add thread

  fetchCount:
    fetched:  0
    fetching: 0
  fetchAllStatus: ->
    return unless (threads = ThreadWatcher.getAll()).length
    for thread in threads
      ThreadWatcher.fetchStatus thread
    return
  fetchStatus: ({boardID, threadID, data}) ->
    return if data.isDead and !Conf['Show Unread Count']
    {fetchCount} = ThreadWatcher
    if fetchCount.fetching is 0
      ThreadWatcher.status.textContent = '...'
      $.addClass ThreadWatcher.refreshButton, 'fa-spin'
    fetchCount.fetching++
    $.ajax "//a.4cdn.org/#{boardID}/thread/#{threadID}.json",
      onloadend: ->
        fetchCount.fetched++
        if fetchCount.fetched is fetchCount.fetching
          fetchCount.fetched = 0
          fetchCount.fetching = 0
          status = ''
          $.rmClass ThreadWatcher.refreshButton, 'fa-spin'
        else
          status = "#{Math.round fetchCount.fetched / fetchCount.fetching * 100}%"
        ThreadWatcher.status.textContent = status

        if @status is 200 and @response
          isDead = !!@response.posts[0].archived
          if isDead and Conf['Auto Prune']
            ThreadWatcher.db.delete {boardID, threadID}
            ThreadWatcher.refresh()
            return

          lastReadPost = ThreadWatcher.unreaddb.get
            boardID: boardID
            threadID: threadID
            defaultValue: 0

          unread = 0

          for postObj in @response.posts[1..]
            if postObj.no > lastReadPost and !QR.db?.get {boardID, threadID, postID: postObj.no}
              unread++

          if isDead isnt data.isDead or unread isnt data.unread
            data.isDead = isDead
            data.unread = unread
            ThreadWatcher.db.set {boardID, threadID, val: data}
            ThreadWatcher.refresh()

        else if @status is 404
          if Conf['Auto Prune']
            ThreadWatcher.db.delete {boardID, threadID}
          else
            data.isDead = true
            delete data.unread
            ThreadWatcher.db.set {boardID, threadID, val: data}
          ThreadWatcher.refresh()

  getAll: ->
    all = []
    for boardID, threads of ThreadWatcher.db.data.boards
      if Conf['Current Board'] and boardID isnt g.BOARD.ID
        continue
      for threadID, data of threads
        all.push {boardID, threadID, data}
    all

  makeLine: (boardID, threadID, data) ->
    x = $.el 'a',
      className: 'fa fa-times'
      href: 'javascript:;'
    $.on x, 'click', ThreadWatcher.cb.rm

    title = $.el 'span',
      textContent: data.excerpt
      className: 'watcher-title'

    count = $.el 'span',
      textContent: if Conf['Show Unread Count'] and data.unread? then "\u00A0(#{data.unread})" else ''
      className: 'watcher-unread'

    link = $.el 'a',
      href: "/#{boardID}/thread/#{threadID}"
      title: data.excerpt
      className: 'watcher-link'
    $.add link, [title, count]

    div = $.el 'div'
    fullID = "#{boardID}.#{threadID}"
    div.dataset.fullID = fullID
    $.addClass div, 'current'     if g.VIEW is 'thread' and fullID is "#{g.BOARD}.#{g.THREADID}"
    $.addClass div, 'dead-thread' if data.isDead
    $.add div, [x, $.tn(' '), link]
    div
  refresh: ->
    nodes = []
    for {boardID, threadID, data} in ThreadWatcher.getAll()
      nodes.push ThreadWatcher.makeLine boardID, threadID, data

    {list} = ThreadWatcher
    $.rmAll list
    $.add list, nodes

    {threads} = g.BOARD
    for threadID in threads.keys
      thread = threads[threadID]
      toggler = $ '.watch-thread-link', thread.OP.nodes.post
      watched = ThreadWatcher.db.get {boardID: thread.board.ID, threadID}
      helper = if watched then ['addClass', 'Unwatch'] else ['rmClass', 'Watch']
      $[helper[0]] toggler, 'watched'
      toggler.title = "#{helper[1]} Thread"

    for refresher in ThreadWatcher.menu.refreshers
      refresher()
    return

  toggle: (thread) ->
    boardID  = thread.board.ID
    threadID = thread.ID
    if ThreadWatcher.db.get {boardID, threadID}
      ThreadWatcher.rm boardID, threadID
    else
      ThreadWatcher.add thread
  add: (thread) ->
    data     = {}
    boardID  = thread.board.ID
    threadID = thread.ID
    if thread.isDead
      if Conf['Auto Prune'] and ThreadWatcher.db.get {boardID, threadID}
        ThreadWatcher.rm boardID, threadID
        return
      data.isDead = true
    data.excerpt  = Get.threadExcerpt thread
    ThreadWatcher.db.set {boardID, threadID, val: data}
    ThreadWatcher.refresh()
    if Conf['Show Unread Count']
      ThreadWatcher.fetchStatus {boardID, threadID, data}
  rm: (boardID, threadID) ->
    ThreadWatcher.db.delete {boardID, threadID}
    ThreadWatcher.refresh()

  convert: (oldFormat) ->
    newFormat = {}
    for boardID, threads of oldFormat
      for threadID, data of threads
        (newFormat[boardID] or= {})[threadID] = excerpt: data.textContent
    newFormat

  menu:
    refreshers: []
    init: ->
      return if !Conf['Thread Watcher']
      menu = @menu = new UI.Menu 'thread watcher'
      $.on $('.menu-button', ThreadWatcher.dialog), 'click', (e) ->
        menu.toggle e, @, ThreadWatcher
      @addHeaderMenuEntry()
      @addMenuEntries()

    addHeaderMenuEntry: ->
      return if g.VIEW isnt 'thread'
      entryEl = $.el 'a',
        href: 'javascript:;'
      Header.menu.addEntry
        el: entryEl
        order: 60
      $.on entryEl, 'click', -> ThreadWatcher.toggle g.threads["#{g.BOARD}.#{g.THREADID}"]
      @refreshers.push ->
        [addClass, rmClass, text] = if $ '.current', ThreadWatcher.list
          ['unwatch-thread', 'watch-thread', 'Unwatch thread']
        else
          ['watch-thread', 'unwatch-thread', 'Watch thread']
        $.addClass entryEl, addClass
        $.rmClass  entryEl, rmClass
        entryEl.textContent = text

    addMenuEntries: ->
      entries = []

      # `Open all` entry
      entries.push
        cb: ThreadWatcher.cb.openAll
        entry:
          el: $.el 'a',
            textContent: 'Open all threads'
        refresh: -> (if ThreadWatcher.list.firstElementChild then $.rmClass else $.addClass) @el, 'disabled'

      # `Prune dead threads` entry
      entries.push
        cb: ThreadWatcher.cb.pruneDeads
        entry:
          el: $.el 'a',
            textContent: 'Prune dead threads'
        refresh: -> (if $('.dead-thread', ThreadWatcher.list) then $.rmClass else $.addClass) @el, 'disabled'

      # `Settings` entries:
      subEntries = []
      for name, conf of Config.threadWatcher
        subEntries.push @createSubEntry name, conf[1]
      entries.push
        entry:
          el: $.el 'span',
            textContent: 'Settings'
          subEntries: subEntries

      for {entry, cb, refresh} in entries
        entry.el.href = 'javascript:;' if entry.el.nodeName is 'A'
        $.on entry.el, 'click', cb if cb
        @refreshers.push refresh.bind entry if refresh
        @menu.addEntry entry
      return
    createSubEntry: (name, desc) ->
      entry =
        type: 'thread watcher'
        el: UI.checkbox name, " #{name}"
      entry.el.title = desc
      input = entry.el.firstElementChild
      $.on input, 'change', $.cb.checked
      $.on input, 'change', ThreadWatcher.refresh if name is 'Current Board' or name is 'Show Unread Count'
      entry
