Keybinds =
  init: ->
    return if !Conf['Keybinds']

    for hotkey of Conf.hotkeys
      $.sync hotkey, Keybinds.sync

    init = ->
      $.off d, '4chanXInitFinished', init
      $.on d, 'keydown', Keybinds.keydown
      for node in $$ '[accesskey]'
        node.removeAttribute 'accesskey'
      return
    $.on d, '4chanXInitFinished', init

  sync: (key, hotkey) ->
    Conf[hotkey] = key

  keydown: (e) ->
    return unless key = Keybinds.keyCode e
    {target} = e
    if target.nodeName in ['INPUT', 'TEXTAREA']
      return unless /(Esc|Alt|Ctrl|Meta|Shift\+\w{2,})/.test key
    unless g.VIEW not in ['index', 'thread'] or g.VIEW is 'index' and Conf['JSON Navigation'] and Conf['Index Mode'] is 'catalog'
      threadRoot = Nav.getThread()
      if op = $ '.op', threadRoot
        thread = Get.postFromNode(op).thread
    switch key
      # QR & Options
      when Conf['Toggle board list']
        return unless Conf['Custom Board Navigation']
        Header.toggleBoardList()
      when Conf['Toggle header']
        Header.toggleBarVisibility()
      when Conf['Open empty QR']
        Keybinds.qr()
      when Conf['Open QR']
        return unless threadRoot
        Keybinds.qr threadRoot
      when Conf['Open settings']
        Settings.open()
      when Conf['Close']
        if Settings.dialog
          Settings.close()
        else if (notifications = $$ '.notification').length
          for notification in notifications
            $('.close', notification).click()
        else if QR.nodes and !QR.nodes.el.hidden and window.getComputedStyle(QR.nodes.form).display isnt 'none'
          if Conf['Persistent QR']
            QR.hide()
          else
            QR.close()
        else if Embedding.lastEmbed
          Embedding.closeFloat()
        else
          return
      when Conf['Spoiler tags']
        return if target.nodeName isnt 'TEXTAREA'
        Keybinds.tags 'spoiler', target
      when Conf['Code tags']
        return if target.nodeName isnt 'TEXTAREA'
        Keybinds.tags 'code', target
      when Conf['Eqn tags']
        return if target.nodeName isnt 'TEXTAREA'
        Keybinds.tags 'eqn', target
      when Conf['Math tags']
        return if target.nodeName isnt 'TEXTAREA'
        Keybinds.tags 'math', target
      when Conf['Toggle sage']
        return unless QR.nodes and !QR.nodes.el.hidden
        Keybinds.sage()
      when Conf['Submit QR']
        return unless QR.nodes and !QR.nodes.el.hidden
        QR.submit() if !QR.status()
      # Index/Thread related
      when Conf['Update']
        switch g.VIEW
          when 'thread'
            return unless Conf['Thread Updater']
            ThreadUpdater.update()
          when 'index'
            return unless Conf['JSON Navigation']
            Index.update()
          else
            return
      when Conf['Watch']
        return unless thread
        ThreadWatcher.toggle thread
      # Images
      when Conf['Expand image']
        return unless ImageExpand.enabled and threadRoot
        Keybinds.img threadRoot
      when Conf['Expand images']
        return unless ImageExpand.enabled and threadRoot
        Keybinds.img threadRoot, true
      when Conf['Open Gallery']
        return unless Gallery.enabled
        Gallery.cb.toggle()
      when Conf['fappeTyme']
        return unless Conf['Fappe Tyme'] and g.VIEW in ['index', 'thread'] and g.BOARD.ID isnt 'f'
        FappeTyme.toggle 'fappe'
      when Conf['werkTyme']
        return if !Conf['Werk Tyme'] or g.VIEW not in ['index', 'thread'] or g.BOARD is 'f'
        return unless Conf['Werk Tyme'] and g.VIEW in ['index', 'thread'] and g.BOARD.ID isnt 'f'
        FappeTyme.toggle 'werk'
      # Board Navigation
      when Conf['Front page']
        if Conf['JSON Navigation'] and !Conf['Use <%= meta.name %> Catalog'] and g.VIEW is 'index'
          Index.userPageNav 1
        else
          window.location = CatalogLinks.index()
      when Conf['Open front page']
        $.open CatalogLinks.index()
      when Conf['Next page']
        return unless g.VIEW is 'index'
        if Conf['JSON Navigation']
          return unless Conf['Index Mode'] in ['paged', 'infinite']
          $('.next button', Index.pagelist).click()
        else
          if form = $ '.next form'
            window.location = form.action
      when Conf['Previous page']
        return unless g.VIEW is 'index'
        if Conf['JSON Navigation']
          return unless Conf['Index Mode'] in ['paged', 'infinite']
          $('.prev button', Index.pagelist).click()
        else
          if form = $ '.prev form'
            window.location = form.action
      when Conf['Search form']
        return unless g.VIEW is 'index'
        searchInput = if Conf['JSON Navigation'] then Index.searchInput else $.id('search-box')
        Header.scrollToIfNeeded searchInput
        searchInput.focus()
      when Conf['Open catalog']
        window.location = CatalogLinks.catalog()
      when Conf['Cycle sort type']
        return unless Conf['JSON Navigation'] and g.VIEW is 'index' and g.BOARD isnt 'f'
        Index.cycleSortType()
      # Thread Navigation
      when Conf['Next thread']
        return if g.VIEW isnt 'index' or !threadRoot
        Nav.scroll +1
      when Conf['Previous thread']
        return if g.VIEW isnt 'index' or !threadRoot
        Nav.scroll -1
      when Conf['Expand thread']
        return if g.VIEW isnt 'index' or !threadRoot
        ExpandThread.toggle thread
      when Conf['Open thread']
        return if g.VIEW isnt 'index' or !threadRoot
        Keybinds.open thread
      when Conf['Open thread tab']
        return if g.VIEW isnt 'index' or !threadRoot
        Keybinds.open thread, true
      # Reply Navigation
      when Conf['Next reply']
        return unless threadRoot
        Keybinds.hl +1, threadRoot
      when Conf['Previous reply']
        return unless threadRoot
        Keybinds.hl -1, threadRoot
      when Conf['Deselect reply']
        return unless threadRoot
        Keybinds.hl  0, threadRoot
      when Conf['Hide']
        return unless thread
        ThreadHiding.toggle thread if ThreadHiding.db
      when Conf['Previous Post Quoting You']
        return unless threadRoot
        QuoteYou.cb.seek 'preceding'
      when Conf['Next Post Quoting You']
        return unless threadRoot
        QuoteYou.cb.seek 'following'
      <% if (tests_enabled) { %>
      when 't'
        return unless threadRoot
        BuildTest.testAll()
      <% } %>
      else
        return
    e.preventDefault()
    e.stopPropagation()

  keyCode: (e) ->
    key = switch kc = e.keyCode
      when 8 # return
        ''
      when 13
        'Enter'
      when 27
        'Esc'
      when 37
        'Left'
      when 38
        'Up'
      when 39
        'Right'
      when 40
        'Down'
      else
        if 48 <= kc <= 57 or 65 <= kc <= 90 # 0-9, A-Z
          String.fromCharCode(kc).toLowerCase()
        else
          null
    if key
      if e.altKey   then key = 'Alt+'   + key
      if e.ctrlKey  then key = 'Ctrl+'  + key
      if e.metaKey  then key = 'Meta+'  + key
      if e.shiftKey then key = 'Shift+' + key
    key

  qr: (thread) ->
    return unless Conf['Quick Reply'] and QR.postingIsEnabled
    QR.open()
    if thread?
      QR.quote.call $ 'input', $('.post.highlight', thread) or thread
    QR.nodes.com.focus()

  tags: (tag, ta) ->
    supported = switch tag
      when 'spoiler'     then !!$ '.postForm input[name=spoiler]'
      when 'code'        then g.BOARD.ID is 'g'
      when 'math', 'eqn' then g.BOARD.ID is 'sci'
    new Notice 'warning', "[#{tag}] tags are not supported on /#{g.BOARD}/.", 20 unless supported

    value    = ta.value
    selStart = ta.selectionStart
    selEnd   = ta.selectionEnd

    ta.value =
      value[...selStart] +
      "[#{tag}]" + value[selStart...selEnd] + "[/#{tag}]" +
      value[selEnd..]

    # Move the caret to the end of the selection.
    range = "[#{tag}]".length + selEnd
    ta.setSelectionRange range, range

    # Fire the 'input' event
    $.event 'input', null, ta

  sage: ->
    isSage  = /sage/i.test QR.nodes.email.value
    QR.nodes.email.value = if isSage
      ""
    else "sage"

  img: (thread, all) ->
    if all
      ImageExpand.cb.toggleAll()
    else
      post = Get.postFromNode $('.post.highlight', thread) or $ '.op', thread
      ImageExpand.toggle post

  open: (thread, tab) ->
    return if g.VIEW isnt 'index'
    url = "/#{thread.board}/thread/#{thread}"
    if tab
      $.open url
    else
      location.href = url

  hl: (delta, thread) ->
    postEl = $ '.reply.highlight', thread

    unless delta
      $.rmClass postEl, 'highlight' if postEl
      return

    if postEl
      {height} = postEl.getBoundingClientRect()
      if Header.getTopOf(postEl) >= -height and Header.getBottomOf(postEl) >= -height # We're at least partially visible
        root = postEl.parentNode
        axis = if delta is +1
          'following'
        else
          'preceding'
        return unless next = $.x "#{axis}-sibling::div[contains(@class,'replyContainer') and not(@hidden) and not(child::div[@class='stub'])][1]/child::div[contains(@class,'reply')]", root
        Header.scrollToIfNeeded next, delta is +1
        @focus next
        $.rmClass postEl, 'highlight'
        return
      $.rmClass postEl, 'highlight'

    replies = $$ '.reply', thread
    replies.reverse() if delta is -1
    for reply in replies
      if delta is +1 and Header.getTopOf(reply) > 0 or delta is -1 and Header.getBottomOf(reply) > 0
        @focus reply
        return

  focus: (post) ->
    $.addClass post, 'highlight'
