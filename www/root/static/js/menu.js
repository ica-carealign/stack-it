function NavMenu(viewObj) {
  var self = this;

  self.items = new Object([
    { 'label': 'Stacks', 'action': viewObj.goToStackList } /*,
    { 'label': 'Config', 'action': viewObj.goToStackList },
    { 'label': 'Users',  'action': viewObj.goToStackList }, */
  ]);

  self.render = function() {
    var menu = jQuery('nav#menu');

    self.items.forEach(function(item) {
      var id = "nav-" + item.label.replace(/\W+/g, '-').toLowerCase();
      menu.append(jQuery('<li><a id="' + id + '" href=""></a></li>'));

      var $link = jQuery('#'+id);
      $link.text(item.label);
      $link.click(function(e) {
          item.action();
          $link.parent().siblings().removeClass("active");
          $link.parent().addClass("active");
          return false;
      });
    });

    menu.children("li:first").addClass("active");
  }
}
