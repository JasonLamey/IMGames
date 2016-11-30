function validate_signup_form()
{
  $.validate(
    {
      modules              : 'date, security',
      form                 : '#signup_form',
      errorMessagePosition : 'inline'
    }
  );
}

function validate_login_form()
{
  $.validate(
    {
      form                 : '#login_form',
      errorMessagePosition : 'inline'
    }
  );
}

function validate_add_product_form()
{
  $.validate(
    {
      form                 : '#admin_add_product_form',
      modules              : 'logic',
      errorMessagePosition : 'inline'
    }
  );
}

function promptForDelete( item, url )
{
  Ply.dialog( 'confirm',
              {
                effect : "3d-flip" // fade, scale, fall, slide, 3d-flip, 3d-sign
              },
              'Are you sure you want to delete >' + item + '<?'
  )
    .always( function(ui)
      {
        if (ui.state)
        {
          window.location.href = url;
          return true;
        }
        else
        {
          return false;
        }
      }
    )
  ;
}

function showSuccess( msg )
{
    notif(
            {
                msg:       "<i class='fa fa-check-circle fa-fw'></i> " + msg,
                type:      'success',
                position:  'center',
                width:     600,
                autohide:  true,
                opacity:   0.9,
                fade:      true,
                clickable: true,
                multiline: true,
            }
    );
}

function showWarning( msg )
{
    notif(
            {
                msg:       "<i class='fa fa-exclamation-circle fa-fw'></i> " + msg,
                type:      'warning',
                position:  'center',
                width:     600,
                autohide:  false,
                opacity:   0.9,
                fade:      true,
                clickable: true,
                multiline: true,
            }
    );
}

function showError( msg )
{
    notif(
            {
                msg:       '<i class="fa fa-exclamation-triangle fa-fw"></i> ' + msg,
                type:      'error',
                position:  'center',
                width:     600,
                autohide:  false,
                opacity:   0.9,
                fade:      true,
                clickable: true,
                multiline: true,
            }
    );
}

function showInfo( msg )
{
    notif(
            {
                msg:       '<i class="fa fa-info-circle fa-fw"></i> ' + msg,
                type:      'info',
                position:  'center',
                width:     600,
                autohide:  false,
                opacity:   0.9,
                fade:      true,
                clickable: true,
                multiline: true,
            }
    );
}

$(function() {
  $('a[data-modal]').click(function(event) {
    $(this).modal(
                  {
                    fadeDuration: 500,
                    fadeDelay:    0.50,
                  }
                 );
    return false;
  });
});

$( function()
{
  $( 'a[rel="ajax:modal"]' ).click( function( event )
   {
    $.ajax(
    {
      url:  $(this).attr('href'),
      type: 'GET',

      success: function( newHTML, textStatus, jqXHR )
      {
        $(newHTML).appendTo('body').modal(
          {
            fadeDuration: 500,
            fadeDelay:    0.50,
          }
        );
      },

      error: function( jqXHR, textStatus, errorThrown )
      {
        showError( 'An error occurred, and we could not send your inquiry. Please try again later.<br>' + errorThrown )
      }
    }
    );

    return false;
  });
});
