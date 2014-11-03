Fourchan =
  init: ->
    return if g.VIEW is 'catalog'

    if g.BOARD.ID is 'g'
      $.globalEval '''
        window.addEventListener('prettyprint', function(e) {
          window.dispatchEvent(new CustomEvent('prettyprint:cb', {
            detail: prettyPrintOne(e.detail)
          }));
        }, false);
      '''
      Post.callbacks.push
        name: 'Parse /g/ code'
        cb:   @code

    if g.BOARD.ID is 'sci'
      # https://github.com/MayhemYDG/4chan-x/issues/645#issuecomment-13704562
      $.globalEval '''
        window.addEventListener('jsmath', function(e) {
          if (!jsMath) return;
          if (jsMath.loaded) {
            // process one post
            jsMath.ProcessBeforeShowing(e.target);
          } else if (jsMath.Autoload && jsMath.Autoload.checked) {
            // load jsMath and process whole document
            jsMath.Autoload.Script.Push('ProcessBeforeShowing', [null]);
            jsMath.Autoload.LoadJsMath();
          }
        }, false);
      '''
      Post.callbacks.push
        name: 'Parse /sci/ math'
        cb:   @math
      CatalogThread.callbacks.push
        name: 'Parse /sci/ math'
        cb:   @math

    $.globalEval '''
      document.addEventListener('PostsInserted', function() {
        var newIDs = document.querySelectorAll('.posteruid.unregistered');
        for (var i = 0; i < newIDs.length; i++) {
          if (currentHighlighted && newIDs[i].className.indexOf('id_' + currentHighlighted) != -1) {
            var post = newIDs[i].parentNode.parentNode.parentNode;
            post.className = 'highlight ' + post.className;
          }
          newIDs[i].addEventListener('click', idClick, false);
          newIDs[i].classList.remove('unregistered');
        }
      }, false);
    '''
    Post.callbacks.push
      name: 'Clickable IDs'
      cb:   @clickableIDs

  code: ->
    return if @isClone
    apply = (e) ->
      pre.innerHTML = e.detail
      $.addClass pre, 'prettyprinted'
    $.on window, 'prettyprint:cb', apply
    for pre in $$ '.prettyprint:not(.prettyprinted)', @nodes.comment
      $.event 'prettyprint', pre.innerHTML, window
    $.off window, 'prettyprint:cb', apply
    return

  math: ->
    return if (@isClone and doc.contains @origin.nodes.root) or !$ '.math', @nodes.comment
    $.asap (=> doc.contains @nodes.comment), =>
      $.event 'jsmath', null, @nodes.comment

  clickableIDs: ->
    return unless @nodes.uniqueID and !doc.contains @nodes.root
    $.addClass @nodes.uniqueID, 'unregistered'
