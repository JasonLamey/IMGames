{
  signup_form =>
  {
    required =>
    [
      ( qw/
        username
        password
        password2
        email
        birthdate
      / ),
    ],
    constraint_methods =>
    {
      email     => Data::FormValidator::Constraints::email(),
      username  => Data::FormValidator::Constraints::FV_length_between( 1, 30 ),
      password  => Data::FormValidator::Constraints::FV_length_between( 1, 50 ),
      password2 => Data::FormValidator::Constraints::FV_length_between( 1, 50 ),
      password  => Data::FormValidator::Constraints::FV_eq_with( 'password2' ),
    },
  },
  login_form =>
  {
    required =>
    [
      ( qw/
        username
        password
      / ),
    ],
  },
  product_review_form =>
  {
    required =>
    [
      ( qw/
        title
        rating
        content
      / ),
    ],
    constraint_methods =>
    {
      title    => Data::FormValidator::Constraints::FV_length_between( 5, 255 ),
      content  => Data::FormValidator::Constraints::FV_min_length( 20 ),
    },
  },
  contact_us_form =>
  {
    required =>
    [
      ( qw/
        name
        email
        email2
        reason
        message
      / ),
    ],
    constraint_methods =>
    {
      email  => Data::FormValidator::Constraints::email(),
      email2 => Data::FormValidator::Constraints::FV_eq_with( 'email2' ),
    }
  },
  user_account_update_form =>
  {
    required =>
    [
      ( qw/
        email
      / ),
    ],
  },
  change_password_form =>
  {
    required =>
    [
      ( qw/
        current_password
        new_password
        confirm_password
      / ),
    ],
    constraint_methods =>
    {
      new_password     => Data::FormValidator::Constraints::FV_length_between( 1, 50 ),
      confirm_password => Data::FormValidator::Constraints::FV_length_between( 1, 50 ),
      new_password     => Data::FormValidator::Constraints::FV_eq_with( 'confirm_password' ),
    },
  },
  admin_new_product_form =>
  {
    required =>
    [
      ( qw/
          name
          product_type_id
          product_subcategory_id
          base_price
          status
          intro
          description
      / ),
    ],
    constraint_methods =>
    {
      name => Data::FormValidator::Constraints::FV_length_between( 1, 255 ),
    },
  },
  admin_edit_product_form =>
  {
    required =>
    [
      ( qw/
          name
          product_type_id
          product_subcategory_id
          base_price
          status
          intro
          description
      / ),
    ],
    constraint_methods =>
    {
      name => Data::FormValidator::Constraints::FV_length_between( 1, 255 ),
    },
  },
  admin_new_product_category_form =>
  {
    required =>
    [
      ( qw/
        category
        shorthand
      / ),
    ],
  },
  admin_new_product_subcategory_form =>
  {
    required =>
    [
      ( qw/
        subcategory
        category_id
      / ),
    ],
  },
  admin_edit_product_category_form =>
  {
    required =>
    [
      ( qw/
        category
        shorthand
      / ),
    ],
  },
  admin_edit_product_subcategory_form =>
  {
    required =>
    [
      ( qw/
        subcategory
        category_id
      / ),
    ],
  },
  admin_add_news_form =>
  {
    required =>
    [
      ( qw/
        title
        content
      / ),
    ],
  },
  admin_edit_news_form =>
  {
    required =>
    [
      ( qw/
        title
        content
      / ),
    ],
  },
  admin_add_event_form =>
  {
    required =>
    [
      ( qw/
        name
        start_date
        end_date
        start_time
        end_time
      / ),
    ],
  },
  admin_edit_event_form =>
  {
    required =>
    [
      ( qw/
        name
        start_date
        end_date
        start_time
        end_time
      / ),
    ],
  },
  admin_add_user_form =>
  {
    required =>
    [
      ( qw/
        username
        password
        email
        birthdate
      / ),
    ],
    constraint_methods =>
    {
      email     => Data::FormValidator::Constraints::email(),
      username  => Data::FormValidator::Constraints::FV_length_between( 1, 30 ),
      password  => Data::FormValidator::Constraints::FV_length_between( 1, 50 ),
    },
  },
  admin_edit_user_form =>
  {
    required =>
    [
      ( qw/
        username
        password
        email
        birthdate
      / ),
    ],
    constraint_methods =>
    {
      email     => Data::FormValidator::Constraints::email(),
      username  => Data::FormValidator::Constraints::FV_length_between( 1, 30 ),
      password  => Data::FormValidator::Constraints::FV_length_between( 1, 50 ),
    },
  },
};
