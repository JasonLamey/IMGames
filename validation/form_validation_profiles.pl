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
  admin_new_product_form =>
  {
    required =>
    [
      ( qw/
          name
          product_type_id
          product_subcategory_id
          base_price
          intro
          description
      / ),
    ],
    constraint_methods =>
    {
      name => Data::FormValidator::Constraints::FV_length_between( 1, 255 ),
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
          intro
          description
      / ),
    ],
    constraint_methods =>
    {
      name => Data::FormValidator::Constraints::FV_length_between( 1, 255 ),
    },
  },
};
