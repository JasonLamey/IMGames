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
      errorMessagePosition : 'inline'
    }
  );
}

function catererBookmarkToggle( caterer_id, user_id, action )
{
    var bookmark_url = "/bookmark_caterer/" + caterer_id + "/user/" + user_id + "/" + action;

    $.ajax(
            {
                url: bookmark_url,
                dataType: 'json',
                success: function( data )
                {
                    if ( data[0].success < 1 )
                    {
                        showError( data[0].message );
                        return false;
                    }
                    if ( action == -1 )
                    {
                        $('#bookmark_caterer').html( '<a href="#" onClick="catererBookmarkToggle( '
                                                        + caterer_id
                                                        + ', '
                                                        + user_id
                                                        + ', 1 )"><i class="fa fa-bookmark"></i> Bookmark Caterer</a>' );
                    }
                    else
                    {
                        $('#bookmark_caterer').html( '<a href="#" onClick="catererBookmarkToggle( '
                                                        + caterer_id
                                                        + ', '
                                                        + user_id
                                                        + ', -1 )"><i class="fa fa-bookmark-o"></i> Unbookmark Caterer</a>' );
                    }
                    showSuccess( data[0].message )
                },
                error: function()
                {
                    showError( 'An error occurred, and we could not bookmark this Caterer. Please try again later.' )
                },
                type: 'GET'
            }
    );
}

function submitCatererInquiryForm ( form )
{
    var data = {};

    $.each( form.elements, function( i, v )
        {
            var input = $(v);
            data[ input.attr( "name" ) ] = input.val();
            delete data["undefined"];
        }
    );

    $.ajax(
            {
                type      : 'POST',
                url       : $( 'input[name=submit_url]' ).val(),
                data      : data,
                dataType  : 'json',
                context   : form,
                cache     : false,
                beforeSend: function() { $('catererInquiryForm').hide(); $('#inqiry-wait').show(); },
                complete  : function() { $('#sendInquiry').foundation('close'); $('#inqiry-wait').hide(); },
            }
    )
    .done( function( data )
        {
            console.log( data );

            if ( ! data[0].success )
            {
                if ( data[0].message )
                {
                    showError( data[0].message )
                }
                else
                {
                    showError( 'An error occurred, and we could not send your inquiry. Please try again later.' )
                }
            }
            else
            {
                showSuccess( data[0].message )
            }
        }
    );
}

function showSuccess( msg )
{
    notif(
            {
                msg:       msg,
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
                msg:       msg,
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
                msg:       msg,
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
                msg:       msg,
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
