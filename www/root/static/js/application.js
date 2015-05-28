jQuery(window).ready(setup);

function alignTableHeaders(tableID) {
  /* Make sure the column headers line up correctly in a table */
  var $th = jQuery(tableID + " thead tr th");
  var $td = jQuery(tableID + " tbody tr").first().find('td');

  /* Fix this */
  for(var i = 0; i < $td.length; i++) {
    $th.eq(i).width($td.eq(i).width() + 2);
  }
}

function setAjaxWaitAnimation() {
  var spinner;
  var spinner_options = {
    'lines':     11,        // The number of lines to draw
    'length':    6,         // The length of each line
    'width':     6,         // The line thickness
    'radius':    15,        // The radius of the inner circle
    'rotate':    0,         // The rotation offset
    'color':     '#171A92', // #rgb or #rrggbb
    'direction': 1,         // 1: clockwise, -1: counterclockwise
    'speed':     1,         // Rounds per second
    'trail':     100,       // Afterglow percentage
    'shadow':    false,     // Whether to render a shadow
    'hwaccel':   true,      // Whether to use hardware acceleration
    'className': 'spinner', // The CSS class to assign to the spinner
    'zIndex':    2e9,       // The z-index (defaults to 2000000000)
    'top':       'auto',    // Top position relative to parent in px
    'left':      'auto'     // Left position relative to parent in px
  };

  jQuery("body").append(jQuery("<div id='spinner'></div>"));
  $("#spinner").center();

  jQuery(document).ajaxStart(function() {
    spinner = new Spinner(spinner_options).spin(document.getElementById("spinner"));
  });

  jQuery(document).ajaxStop(function() {
    if(spinner != undefined) {
      spinner.stop();
      delete spinner;
    }
  });
}

function setup() {
  var viewObj = new ViewModel();
  var menuObj = new NavMenu(viewObj);

  menuObj.render();

  setAjaxWaitAnimation();
  ko.applyBindings(viewObj);
  viewObj.goToStackList();
}

function displayMessage(message, cssClass, persistent) {
  persistent = typeof persistent == 'undefined' ? 0 : persistent;

  if(!message) {
    message  = "The server encountered an error!  ";
    message += "Check the server logs for more information.";
  }

  cssClass = cssClass || "MessageError";

  jQuery("#Message").removeClass();

  jQuery("#Message").addClass("MessagesDiv");
  jQuery("#Message").addClass(cssClass);

  jQuery("#Message span").text(message);

  if(persistent == 0) {
    jQuery("#Message").fadeIn(15);
    jQuery("#Message").fadeOut(9000);
  } else {
    jQuery("#Message").show();
  }
}

function hideMessage() {
  jQuery("#Message").hide();
}
