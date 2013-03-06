Main =
  init: ->
    # Use the Config variable to create the flat Conf object, which conveniently stores keyed configuration values.
    Main.flatten null, Config

    # Load user configuration from localStorage.
    for key, val of Conf
      Conf[key] = $.get key, val

    path = location.pathname
    pathname = path[1..].split '/'
    [g.BOARD, temp] = pathname
    switch temp
      when 'res'
        g.REPLY = true
        g.THREAD_ID = pathname[2]
      when 'catalog'
        g.CATALOG = true

    # Check if the current board we're on is SFW or not, so we can handle options that need to know that.
    if ['b', 'd', 'e', 'gif', 'h', 'hc', 'hm', 'hr', 'pol', 'r', 'r9k', 'rs', 's', 'soc', 't', 'u', 'y'].contains g.BOARD
      g.TYPE = 'nsfw'

    # Scope a local _conf variable for performance.
    _conf = Conf

    # Setup Fill some per board configuration values with their global equivalents.
    if _conf["Interval per board"]
      Conf["Interval_"   + g.BOARD] = $.get "Interval_"   + g.BOARD, Conf["Interval"]
      Conf["BGInterval_" + g.BOARD] = $.get "BGInterval_" + g.BOARD, Conf["BGInteval"]

    switch location.hostname
      when 'sys.4chan.org'
        if /report/.test location.search
          $.ready ->
            form  = $ 'form'
            field = $.id 'recaptcha_response_field'
            $.on field, 'keydown', (e) ->
              $.globalEval('Recaptcha.reload()') if e.keyCode is 8 and not e.target.value
            $.on form, 'submit', (e) ->
              e.preventDefault()
              response = field.value.trim()
              field.value = "#{response} #{response}" unless /\s/.test response
              form.submit()
        return

      when 'images.4chan.org'
        $.ready ->
          if /^4chan - 404/.test(d.title) and _conf['404 Redirect']
            path = location.pathname.split '/'
            url  = Redirect.image path[1], path[3]
            location.href = url if url
        return

    # Load user themes, mascots, and their various statuses.
    userNavigation = $.get "userNavigation", Navigation

    # Prune objects that have expired.
    Main.prune()

    # Major features

    now = Date.now()
    if _conf['Check for Updates'] and $.get('lastUpdate', 0) < now - 18 * $.HOUR
      $.ready ->
        $.on window, 'message', Main.message
        $.set 'lastUpdate', now
        $.add d.head, $.el 'script',
          src: 'https://github.com/zixaphir/appchan-x/raw/4chanX/latest.js'

    settings = JSON.parse(localStorage.getItem '4chan-settings') or {}
    settings.disableAll = true
    localStorage.setItem '4chan-settings', JSON.stringify settings

    if g.CATALOG
      $.ready Main.catalog
    else
      Main.features()

  catalog: ->
    _conf = Conf
    if _conf['Catalog Links']
      CatalogLinks.init()

    if _conf['Thread Hiding']
      ThreadHiding.init()

    $.ready ->
      if _conf['Custom Navigation']
        CustomNavigation.init()

      for nav in ['boardNavDesktop', 'boardNavDesktopFoot']
        if a = $ "a[href*='/#{g.BOARD}/']", $.id nav
          # Gotta make it work in temporary boards.
          $.addClass a, 'current'
      return

  features: ->
    _conf = Conf

    Style.init()

    if _conf['Filter']
      Filter.init()

    if _conf['Reply Hiding']
      ReplyHiding.init()

    if _conf['Reply Hiding'] or _conf['Reply Hiding Link'] or _conf['Filter']
      StrikethroughQuotes.init()

    if _conf['Anonymize']
      Anonymize.init()

    if _conf['Time Formatting']
      Time.init()

    if _conf['File Info Formatting']
      FileInfo.init()

    if _conf['Sauce']
      Sauce.init()

    if _conf['Reveal Spoilers']
      RevealSpoilers.init()

    if _conf['Image Auto-Gif']
      AutoGif.init()

    if _conf['Png Thumbnail Fix']
      PngFix.init()

    if _conf['Image Hover']
      ImageHover.init()

    if _conf['Menu']
      Menu.init()

      if _conf['Report Link']
        ReportLink.init()

      if _conf['Delete Link']
        DeleteLink.init()

      if _conf['Filter']
        Filter.menuInit()

      if _conf['Archive Link']
        ArchiveLink.init()

      if _conf['Download Link']
        DownloadLink.init()

      if _conf['Embed Link']
        EmbedLink.init()

      if _conf['Thread Hiding Link']
        ThreadHideLink.init()

      if _conf['Reply Hiding Link']
        ReplyHideLink.init()

    if _conf['Linkify']
      Linkify.init()

    if _conf['Resurrect Quotes']
      Quotify.init()

    if _conf['Remove Spoilers']
      RemoveSpoilers.init()

    if _conf['Quote Inline']
      QuoteInline.init()

    if _conf['Quote Preview']
      QuotePreview.init()

    if _conf['Quote Backlinks']
      QuoteBacklink.init()

    if _conf['Mark Owned Posts']
      MarkOwn.init()

    if _conf['Indicate OP quote']
      QuoteOP.init()

    if _conf['Indicate Cross-thread Quotes']
      QuoteCT.init()

    if _conf['Color user IDs']
      IDColor.init()

    if _conf['Replace GIF'] or _conf['Replace PNG'] or _conf['Replace JPG']
      ImageReplace.init()

    $.ready Main.featuresReady

  featuresReady: ->
    _conf = Conf
    if /^4chan - 404/.test d.title
      if _conf['404 Redirect'] and /^\d+$/.test g.THREAD_ID
        location.href =
          Redirect.to
            board:    g.BOARD
            threadID: g.THREAD_ID
            postID:   location.hash
      return
    return unless $.id 'navtopright'
    $.addClass d.body, $.engine
    $.addClass d.body, 'fourchan_x'

    if _conf['Custom Navigation']
      CustomNavigation.init()

    for nav in ['boardNavDesktop', 'boardNavDesktopFoot']
      if a = $ "a[href*='/#{g.BOARD}/']", $.id nav
        # Gotta make it work in temporary boards.
        $.addClass a, 'current'

    now = Date.now()

    Favicon.init()
    Options.init()

    # Major features.

    if _conf['Quick Reply']
      QR.init()

    if _conf['Image Expansion']
      ImageExpand.init()

    if _conf['Catalog Links']
      CatalogLinks.init()

    if _conf['Thread Watcher']
      Watcher.init()

    if _conf['Keybinds']
      Keybinds.init()

    if _conf['Fappe Tyme']
      FappeTyme.init()

    if g.REPLY
      if _conf['Prefetch']
        Prefetch.init()

      if _conf['Thread Updater']
        Updater.init()

      if _conf['Thread Stats']
        ThreadStats.init()

      if _conf['Reply Navigation']
        Nav.init()

      if _conf['Post in Title']
        TitlePost.init()

      if _conf['Unread Count'] or _conf['Unread Favicon']
        Unread.init()

    else # not reply
      if _conf['Thread Hiding']
        ThreadHiding.init()

      if _conf['Thread Expansion']
        ExpandThread.init()

      if _conf['Comment Expansion']
        ExpandComment.init()

      if _conf['Index Navigation']
        Nav.init()

    board = $ '.board'
    nodes = []
    for node in $$ '.postContainer', board
      nodes.push Main.preParse node
    Main.node nodes, ->
      if d.readyState is "complete"
        return true
      false

    # Execute these scripts on inserted posts, not page init.
    Main.hasCodeTags = !! $ 'script[src^="//static.4chan.org/js/prettify/prettify"]'

    if MutationObserver
      Main.observer = new MutationObserver Main.observe
      Main.observer.observe board,
        childList: true
        subtree: true
      if g.REPLY
        $.ready ->
          Main.observer.disconnect()
    else
      $.on board, 'DOMNodeInserted', Main.listener
      $.ready ->
        $.off board, 'DOMNodeInserted', Main.listener
    return

  prune: ->
    now = Date.now()
    g.hiddenReplies = $.get "hiddenReplies/#{g.BOARD}/", {}
    if $.get('lastChecked', 0) < now - 1*$.DAY
      $.set 'lastChecked', now

      cutoff        = now - 7*$.DAY
      hiddenThreads = $.get "hiddenThreads/#{g.BOARD}/", {}
      ownedPosts    = $.get 'ownedPosts', {}
      titles        = $.get 'CachedTitles', {}

      for id, timestamp of hiddenThreads
        if timestamp < cutoff
          delete hiddenThreads[id]

      for id, timestamp of g.hiddenReplies
        if timestamp < cutoff
          delete g.hiddenReplies[id]

      for id, timestamp of ownedPosts
        if timestamp < cutoff
          delete ownedPosts[id]

      for id of titles
        if titles[id][1] < cutoff
          delete titles[id]

      $.set "hiddenThreads/#{g.BOARD}/", hiddenThreads
      $.set "hiddenReplies/#{g.BOARD}/", g.hiddenReplies
      $.set 'CachedTitles',              titles
      $.set 'ownedPosts',                ownedPosts

  flatten: (parent, obj) ->
    if obj instanceof Array
      Conf[parent] = obj[0]
    else if typeof obj is 'object'
      for key, val of obj
        Main.flatten key, val
    else # string or number
      Conf[parent] = obj
    return

  message: (e) ->
    {version} = e.data
    if version and version isnt Main.version
      xupdate = $.el 'div',
        id: 'xupdater'
        className: 'reply'
        innerHTML:
          "<a href=https://raw.github.com/zixaphir/appchan-x/#{version}/appchan_x.user.js>An updated version of Appchan X (v#{version}) is available.</a> <a href=javascript:; id=dismiss_xupdate>dismiss</a>"
      $.on $('#dismiss_xupdate', xupdate), 'click', -> $.rm xupdate
      $.prepend $.id('delform'), xupdate

  preParse: (node) ->
    parentClass = if parent = node.parentNode then parent.className else ""
    el   = $ '.post', node
    post =
      root:        node
      el:          el
      class:       el.className
      ID:          el.id.match(/\d+$/)[0]
      threadID:    g.THREAD_ID or if parent then $.x('ancestor::div[parent::div[@class="board"]]', node).id.match(/\d+$/)[0]
      isArchived:  parentClass.contains    'archivedPost'
      isInlined:   /\binline\b/.test       parentClass
      isCrosspost: parentClass.contains    'crosspost'
      blockquote:  el.lastElementChild
      quotes:      el.getElementsByClassName 'quotelink'
      backlinks:   el.getElementsByClassName 'backlink'
      fileInfo:    false
      img:         false
    if img = $ 'img[data-md5]', el
      # Make sure to not add deleted images,
      # those do not have a data-md5 attribute.
      imgParent     = img.parentNode
      post.img      = img
      post.fileInfo = imgParent.previousElementSibling
      post.hasPdf   = /\.pdf$/.test imgParent.href
    Main.prettify post.blockquote
    post

  node: (nodes, notify) ->
    for callback in Main.callbacks
      try
        callback node for node in nodes
      catch err
        alert "4chan X has experienced an error. You can help by sending this snippet to:\nhttps://github.com/zixaphir/appchan-x/issues\n\n#{Main.version}\n#{window.location}\n#{navigator.userAgent}\n\n#{err}\n#{err.stack}" if notify
    return

  observe: (mutations) ->
    nodes = []
    for mutation in mutations
      nodes.push Main.preParse addedNode for addedNode in mutation.addedNodes when /\bpostContainer\b/.test addedNode.className
    Main.node nodes if nodes.length

  listener: (e) ->
    {target} = e
    if /\bpostContainer\b/.test(target.className)
      Main.node [Main.preParse target]

  prettify: (bq) ->
    return unless Main.hasCodeTags
    switch g.BOARD
      when 'g'
        code = ->
          for pre in document.getElementById('_id_').getElementsByClassName 'prettyprint'
            pre.innerHTML = prettyPrintOne pre.innerHTML.replace /\s/g, '&nbsp;'
          return
      when 'sci'
        code = ->
          jsMath.Process document.getElementById '_id_'
          return
      else
        return
    $.globalEval "#{code}".replace '_id_', bq.id
  namespace: '<%= pkg.name.replace(/-/g, '_') %>.'
  version:   '<%= pkg.version %>'
  callbacks: []
