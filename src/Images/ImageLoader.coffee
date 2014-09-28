ImageLoader =
  init: ->
    return if g.VIEW is 'catalog'
    return unless Conf['Image Prefetching'] or Conf['Replace JPG'] or Conf['Replace PNG'] or Conf['Replace GIF'] or Conf['Replace WEBM']

    Post.callbacks.push
      name: 'Image Replace'
      cb:   @node

    $.on d, 'PostsInserted', ->
      g.posts.forEach ImageLoader.prefetch

    if Conf['Replace WEBM']
      $.on d, 'scroll visibilitychange 4chanXInitFinished PostsInserted', ->
        # Special case: Quote previews are off screen when inserted into document, but quickly moved on screen.
        qpClone = $.id('qp')?.firstElementChild
        g.posts.forEach (post) ->
          for post in [post, post.clones...] when post.file and post.file.isVideo and post.file.isReplaced
            {thumb} = post.file
            if Header.isNodeVisible(thumb) or post.nodes.root is qpClone then thumb.play() else thumb.pause()
          return

    return unless Conf['Image Prefetching']

    prefetch = $.el 'label',
      <%= html('<input type="checkbox" name="prefetch"> Prefetch Images') %>

    @el = prefetch.firstElementChild
    $.on @el, 'change', ->
      if Conf['prefetch'] = @checked
        g.posts.forEach ImageLoader.prefetch

    Header.menu.addEntry
      el: prefetch
      order: 104

  node: ->
    return if @isClone or !@file
    ImageLoader.replaceVideo @ if Conf['Replace WEBM'] and @file.isVideo
    ImageLoader.prefetch @

  replaceVideo: (post) ->
    {file} = post
    {thumb} = file
    video = $.el 'video',
      preload:     'none'
      loop:        true
      poster:      thumb.src
      textContent: thumb.alt
      className:   thumb.className
    video.dataset.md5 = thumb.dataset.md5
    video.style[attr] = thumb.style[attr] for attr in ['height', 'width', 'maxHeight', 'maxWidth']
    video.src         = file.URL
    $.on video, 'mouseover', ImageHover.mouseover post if Conf['Image Hover']
    $.replace thumb, video
    file.thumb      = video
    file.isReplaced = true

  prefetch: (post) ->
    {file} = post
    return unless file
    {isImage, isVideo, thumb, URL} = file
    return if file.isPrefetched or !(isImage or isVideo) or post.isHidden or post.thread.isHidden
    type    = if (match = URL.match(/\.([^.]+)$/)[1].toUpperCase()) is 'JPEG' then 'JPG' else match
    replace = Conf["Replace #{type}"] and !/spoiler/.test thumb.src
    return unless replace or Conf['prefetch']
    return unless [post, post.clones...].some (clone) -> doc.contains clone.nodes.root
    file.isPrefetched = true
    if isVideo and file.isReplaced
      clone.file.thumb.preload = 'auto' for clone in post.clones
      thumb.preload = 'auto'
      # XXX Cloned video elements with poster in Firefox cause momentary display of image loading icon.
      if !chrome?
        $.on thumb, 'loadeddata', -> @removeAttribute 'poster'
      return
    el = $.el if isImage then 'img' else 'video'
    if replace and isImage
      $.on el, 'load', ->
        for clone in post.clones
          clone.file.thumb.src = URL
          clone.file.isReplaced = true
        thumb.src = URL
        file.isReplaced = true
    el.src = URL
