Header =
  init: ->
    @menu = new UI.Menu 'header'

    menuButton = $.el 'span',
      className: 'menu-button'
    $.extend menuButton, <%= html('<i></i>') %>

    barFixedToggler     = UI.checkbox 'Fixed Header',               ' Fixed Header'
    headerToggler       = UI.checkbox 'Header auto-hide',           ' Auto-hide header'
    scrollHeaderToggler = UI.checkbox 'Header auto-hide on scroll', ' Auto-hide header on scroll'
    barPositionToggler  = UI.checkbox 'Bottom Header',              ' Bottom header'
    linkJustifyToggler  = UI.checkbox 'Centered links',             ' Centered links'
    customNavToggler    = UI.checkbox 'Custom Board Navigation',    ' Custom board navigation'
    footerToggler       = UI.checkbox 'Bottom Board List',          ' Hide bottom board list'
    shortcutToggler     = UI.checkbox 'Shortcut Icons',             ' Shortcut Icons'
    editCustomNav = $.el 'a',
      textContent: 'Edit custom board navigation'
      href: 'javascript:;'

    @barFixedToggler     = barFixedToggler.firstElementChild
    @scrollHeaderToggler = scrollHeaderToggler.firstElementChild
    @barPositionToggler  = barPositionToggler.firstElementChild
    @linkJustifyToggler  = linkJustifyToggler.firstElementChild
    @headerToggler       = headerToggler.firstElementChild
    @footerToggler       = footerToggler.firstElementChild
    @shortcutToggler     = shortcutToggler.firstElementChild
    @customNavToggler    = customNavToggler.firstElementChild

    $.on menuButton,           'click',  @menuToggle
    $.on @headerToggler,       'change', @toggleBarVisibility
    $.on @barFixedToggler,     'change', @toggleBarFixed
    $.on @barPositionToggler,  'change', @toggleBarPosition
    $.on @scrollHeaderToggler, 'change', @toggleHideBarOnScroll
    $.on @linkJustifyToggler,  'change', @toggleLinkJustify
    $.on @headerToggler,       'change', @toggleBarVisibility
    $.on @footerToggler,       'change', @toggleFooterVisibility
    $.on @shortcutToggler,     'change', @toggleShortcutIcons
    $.on @customNavToggler,    'change', @toggleCustomNav
    $.on editCustomNav,        'click',  @editCustomNav

    @setBarFixed        Conf['Fixed Header']
    @setHideBarOnScroll Conf['Header auto-hide on scroll']
    @setBarVisibility   Conf['Header auto-hide']
    @setLinkJustify     Conf['Centered links']
    @setShortcutIcons   Conf['Shortcut Icons']

    $.sync 'Fixed Header',               @setBarFixed
    $.sync 'Header auto-hide on scroll', @setHideBarOnScroll
    $.sync 'Bottom Header',              @setBarPosition
    $.sync 'Shortcut Icons',             @setShortcutIcons
    $.sync 'Header auto-hide',           @setBarVisibility
    $.sync 'Centered links',             @setLinkJustify

    @addShortcut menuButton

    @menu.addEntry
      el: $.el 'span',
        textContent: 'Header'
      order: 107
      subEntries: [
          el: barFixedToggler
        ,
          el: headerToggler
        ,
          el: scrollHeaderToggler
        ,
          el: barPositionToggler
        ,
          el: linkJustifyToggler
        ,
          el: footerToggler
        ,
          el: shortcutToggler
        ,
          el: customNavToggler
        ,
          el: editCustomNav
      ]

    $.on window, 'load hashchange', Header.hashScroll
    $.on d, 'CreateNotification', @createNotification

    $.asap (-> d.body), =>
      return unless Main.isThisPageLegit()
      # Wait for #boardNavMobile instead of #boardNavDesktop,
      # it might be incomplete otherwise.
      $.asap (-> $.id('boardNavMobile') or d.readyState isnt 'loading'), ->
        Header.footer = footer = $.id('boardNavDesktop').cloneNode true
        footer.id = 'boardNavDesktopFoot'
        $.rm $('#navtopright', footer)
        if a = $ "a[href*='/#{g.BOARD}/']", footer
          a.className = 'current'
        Header.setFooterVisibility Conf['Bottom Board List']
        $.sync 'Bottom Board List', Header.setFooterVisibility
        Main.ready ->
          $.rm oldFooter if oldFooter = $.id 'boardNavDesktopFoot'
          $.globalEval 'window.cloneTopNav = function() {};'
          $.before $.id('absbot'), footer
        Header.setBoardList()
      $.prepend d.body, @bar
      $.add d.body, Header.hover
      @setBarPosition Conf['Bottom Header']
      @

    Main.ready =>
      if g.VIEW is 'catalog' or !Conf['Disable Native Extension']
        cs = $.el 'a', href: 'javascript:;'
        if g.VIEW is 'catalog'
          cs.title = cs.textContent = 'Catalog Settings'
          cs.className = 'fa fa-book'
        else
          cs.title = cs.textContent = '4chan Settings'
          cs.className = 'fa fa-leaf'
        $.on cs, 'click', () ->
          $.id('settingsWindowLink').click()
        @addShortcut cs

    @enableDesktopNotifications()

  bar: $.el 'div',
    id: 'header-bar'

  noticesRoot: $.el 'div',
    id: 'notifications'

  shortcuts: $.el 'span',
    id: 'shortcuts'

  hover: $.el 'div',
    id: 'hoverUI'

  toggle: $.el 'div',
    id: 'scroll-marker'

  setBoardList: ->
    Header.boardList = boardList = $.el 'span',
      id: 'board-list'
    $.extend boardList, <%= html(
      '<span id="custom-board-list"></span>' +
      '<span id="full-board-list" hidden>' +
        '<span class="hide-board-list-container brackets-wrap"><a href="javascript:;" class="hide-board-list-button">&nbsp;-&nbsp;</a></span> ' +
        '<span class="boardList"></span>' +
      '</span>'
    ) %>

    btn = $('.hide-board-list-button', boardList)
    $.on btn, 'click', Header.toggleBoardList

    nodes = []
    spacer = -> $.el 'span', className: 'spacer'
    for node in $('#boardNavDesktop > .boardList').childNodes
      switch node.nodeName
        when '#text'
          for chr in node.nodeValue
            span = $.el 'span', textContent: chr
            span.className = 'space' if chr is ' '
            nodes.push spacer() if chr is ']'
            nodes.push span
            nodes.push spacer() if chr is '['
        when 'A'
          a = node.cloneNode true
          a.className = 'current' if a.pathname.split('/')[1] is g.BOARD.ID
          nodes.push a
    $.add $('.boardList', boardList), nodes

    $.add Header.bar, [Header.boardList, Header.shortcuts, Header.noticesRoot, Header.toggle]

    Header.setCustomNav Conf['Custom Board Navigation']
    Header.generateBoardList Conf['boardnav']

    $.sync 'Custom Board Navigation', Header.setCustomNav
    $.sync 'boardnav', Header.generateBoardList

  generateBoardList: (boardnav) ->
    list = $ '#custom-board-list', Header.boardList
    $.rmAll list
    return unless boardnav
    boardnav = boardnav.replace /(\r\n|\n|\r)/g, ' '
    as = $$ '#full-board-list a[title]', Header.boardList
    nodes = boardnav.match(/[\w@]+(-(all|title|replace|full|index|catalog|archive|expired|text:"[^"]+"(,"[^"]+")?))*|[^\w@]+/g).map (t) ->
      if /^[^\w@]/.test t
        return $.tn t
      text = url = null
      t = t.replace /-text:"([^"]+)"(?:,"([^"]+)")?/g, (m0, m1, m2) ->
        text = m1
        url = m2
        ''
      if /^toggle-all/.test t
        a = $.el 'a',
          className: 'show-board-list-button'
          textContent: text or '+'
          href: 'javascript:;'
        $.on a, 'click', Header.toggleBoardList
        return a
      if /^external/.test t
        a = $.el 'a',
          href: url or 'javascript:;'
          textContent: text or '+'
          className: 'external'
        return a
      boardID = if /^current/.test t
        g.BOARD.ID
      else
        t.match(/^[^-]+/)[0]
      for a in as
        if a.textContent is boardID
          a = a.cloneNode true

          a.textContent = if /-title/.test(t) or /-replace/.test(t) and $.hasClass a, 'current'
            a.title
          else if /-full/.test t
            "/#{boardID}/ - #{a.title}"
          else if text
            text
          else
            a.textContent

          if m = t.match /-(index|catalog)/
            a.dataset.only = m[1]
            a.href = CatalogLinks[m[1]] boardID
            $.addClass a, 'catalog' if m[1] is 'catalog'

          if /-archive/.test t
            if href = Redirect.to 'board', {boardID}
              a.href = href
            else
              return $.tn a.textContent

          if /-expired/.test t
            if boardID not in ['b', 'f']
              a.href = "/#{boardID}/archive"
            else
              return $.tn a.textContent

          $.addClass a, 'navSmall' if boardID is '@'
          return a
      $.tn t
    $.add list, nodes
    $.ready CatalogLinks.initBoardList

  toggleBoardList: ->
    {bar}  = Header
    custom = $ '#custom-board-list', bar
    full   = $ '#full-board-list',   bar
    showBoardList = !full.hidden
    custom.hidden = !showBoardList
    full.hidden   =  showBoardList

  setLinkJustify: (centered) ->
    Header.linkJustifyToggler.checked = centered
    if centered
      $.addClass doc, 'centered-links'
    else
      $.rmClass doc, 'centered-links'

  toggleLinkJustify: ->
    $.event 'CloseMenu'
    centered = if @nodeName is 'INPUT'
      @checked
    Header.setLinkJustify centered
    $.set 'Centered links', centered

  setBarFixed: (fixed) ->
    Header.barFixedToggler.checked = fixed
    if fixed
      $.addClass doc, 'fixed'
      $.addClass Header.bar, 'dialog'
    else
      $.rmClass doc, 'fixed'
      $.rmClass Header.bar, 'dialog'

  toggleBarFixed: ->
    $.event 'CloseMenu'

    Header.setBarFixed @checked

    Conf['Fixed Header'] = @checked
    $.set 'Fixed Header',  @checked

  setShortcutIcons: (show) ->
    Header.shortcutToggler.checked = show
    if show
      $.addClass doc, 'shortcut-icons'
    else
      $.rmClass doc, 'shortcut-icons'

  toggleShortcutIcons: ->
    $.event 'CloseMenu'

    Header.setShortcutIcons @checked

    Conf['Shortcut Icons'] = @checked
    $.set 'Shortcut Icons',  @checked

  setBarVisibility: (hide) ->
    Header.headerToggler.checked = hide
    $.event 'CloseMenu'
    (if hide then $.addClass else $.rmClass) Header.bar, 'autohide'
    (if hide then $.addClass else $.rmClass) doc, 'autohide'

  toggleBarVisibility: ->
    hide = if @nodeName is 'INPUT'
      @checked
    else
      !$.hasClass Header.bar, 'autohide'
    # set checked status if called from keybind
    @checked = hide

    $.set 'Header auto-hide', Conf['Header auto-hide'] = hide
    Header.setBarVisibility hide
    message = "The header bar will #{if hide
      'automatically hide itself.'
    else
      'remain visible.'}"
    new Notice 'info', message, 2

  setHideBarOnScroll: (hide) ->
    Header.scrollHeaderToggler.checked = hide
    if hide
      $.on window, 'scroll', Header.hideBarOnScroll
      return
    $.off window, 'scroll', Header.hideBarOnScroll
    $.rmClass Header.bar, 'scroll'
    $.rmClass Header.bar, 'autohide' unless Conf['Header auto-hide']

  toggleHideBarOnScroll: (e) ->
    hide = @checked
    $.cb.checked.call @
    Header.setHideBarOnScroll hide

  hideBarOnScroll: ->
    offsetY = window.pageYOffset
    if offsetY > (Header.previousOffset or 0)
      $.addClass Header.bar, 'autohide', 'scroll'
    else
      $.rmClass Header.bar,  'autohide', 'scroll'
    Header.previousOffset = offsetY

  setBarPosition: (bottom) ->
    Header.barPositionToggler.checked = bottom
    $.event 'CloseMenu'
    args = if bottom then [
      'bottom-header'
      'top-header'
      'bottom'
      'after'
    ] else [
      'top-header'
      'bottom-header'
      'top'
      'add'
    ]

    $.addClass doc, args[0]
    $.rmClass  doc, args[1]
    Header.bar.parentNode.className = args[2]
    $[args[3]] Header.bar, Header.noticesRoot

  toggleBarPosition: ->
    $.cb.checked.call @
    Header.setBarPosition @checked

  setFooterVisibility: (hide) ->
    Header.footerToggler.checked = hide
    Header.footer.hidden = hide

  toggleFooterVisibility: ->
    $.event 'CloseMenu'
    hide = if @nodeName is 'INPUT'
      @checked
    else
      !!Header.footer.hidden
    Header.setFooterVisibility hide
    $.set 'Bottom Board List', hide
    message = if hide
      'The bottom navigation will now be hidden.'
    else
      'The bottom navigation will remain visible.'
    new Notice 'info', message, 2

  setCustomNav: (show) ->
    Header.customNavToggler.checked = show
    cust = $ '#custom-board-list', Header.bar
    full = $ '#full-board-list',   Header.bar
    btn = $ '.hide-board-list-container', full
    [cust.hidden, full.hidden, btn.hidden] = if show
      [false, true, false]
    else
      [true, false, true]

  toggleCustomNav: ->
    $.cb.checked.call @
    Header.setCustomNav @checked

  editCustomNav: ->
    Settings.open 'Advanced'
    settings = $.id 'fourchanx-settings'
    $('textarea[name=boardnav]', settings).focus()

  hashScroll: ->
    hash = @location.hash[1..]
    return unless /^p\d+$/.test(hash) and post = $.id hash
    return if (Get.postFromRoot post).isHidden

    Header.scrollTo post

  scrollTo: (root, down, needed) ->
    if down
      x = Header.getBottomOf root
      if Conf['Header auto-hide on scroll'] and Conf['Bottom header']
        {height} = Header.bar.getBoundingClientRect()
        if x <= 0
          x += height if !Header.isHidden()
        else
          x -= height if  Header.isHidden()
      window.scrollBy 0, -x unless needed and x >= 0
    else
      x = Header.getTopOf root
      if Conf['Header auto-hide on scroll'] and !Conf['Bottom header']
        {height} = Header.bar.getBoundingClientRect()
        if x >= 0
          x += height if !Header.isHidden()
        else
          x -= height if  Header.isHidden()
      window.scrollBy 0,  x unless needed and x >= 0

  scrollToIfNeeded: (root, down) ->
    Header.scrollTo root, down, true

  getTopOf: (root) ->
    {top} = root.getBoundingClientRect()
    if Conf['Fixed Header'] and not Conf['Bottom Header']
      headRect = Header.toggle.getBoundingClientRect()
      top     -= headRect.top + headRect.height
    top

  getBottomOf: (root) ->
    {clientHeight} = doc
    bottom = clientHeight - root.getBoundingClientRect().bottom
    if Conf['Bottom Header']
      headRect = Header.toggle.getBoundingClientRect()
      bottom  -= clientHeight - headRect.bottom + headRect.height
    bottom
  isNodeVisible: (node) ->
    return false if d.hidden or !doc.contains node
    {height} = node.getBoundingClientRect()
    Header.getTopOf(node) + height >= 0 and Header.getBottomOf(node) + height >= 0
  isHidden: ->
    {top} = Header.bar.getBoundingClientRect()
    if Conf['Bottom header']
      top is doc.clientHeight
    else
      top < 0

  addShortcut: (el) ->
    shortcut = $.el 'span',
      className: 'shortcut brackets-wrap'
    $.add shortcut, el
    $.prepend Header.shortcuts, shortcut

  rmShortcut: (el) ->
    $.rm el.parentElement

  menuToggle: (e) ->
    Header.menu.toggle e, @, g

  createNotification: (e) ->
    {type, content, lifetime} = e.detail
    notice = new Notice type, content, lifetime

  areNotificationsEnabled: false
  enableDesktopNotifications: ->
    return unless window.Notification and Conf['Desktop Notifications']
    switch Notification.permission
      when 'granted'
        Header.areNotificationsEnabled = true
        return
      when 'denied'
        # requestPermission doesn't work if status is 'denied',
        # but it'll still work if status is 'default'.
        return

    el = $.el 'span',
      <%= html(
        '${g.NAME} needs your permission to show desktop notifications. ' +
        '[<a href="${g.FAQ}#why-is-4chan-x-asking-for-permission-to-show-desktop-notifications" target="_blank">FAQ</a>]<br>' +
        '<button>Authorize</button> or <button>Disable</button>'
      ) %>
    [authorize, disable] = $$ 'button', el
    $.on authorize, 'click', ->
      Notification.requestPermission (status) ->
        Header.areNotificationsEnabled = status is 'granted'
        return if status is 'default'
        notice.close()
    $.on disable, 'click', ->
      $.set 'Desktop Notifications', false
      notice.close()
    notice = new Notice 'info', el
