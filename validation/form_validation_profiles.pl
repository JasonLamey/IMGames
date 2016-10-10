{
  signup_form => {
                    required => [
                                  ( qw/
                                      username
                                      password
                                      password2
                                      email
                                      birthdate
                                  / ),
                    ],
                    constraint_methods => {
                                            email     => Data::FormValidator::Constraints::email(),
                                            username  => Data::FormValidator::Constraints::FV_length_between( 1, 30 ),
                                            password  => Data::FormValidator::Constraints::FV_length_between( 1, 50 ),
                                            password2 => Data::FormValidator::Constraints::FV_length_between( 1, 50 ),
                                            password  => Data::FormValidator::Constraints::FV_eq_with( 'password2' ),
                    },
  },
  login_form => {
                  required => [
                                ( qw/
                                    username
                                    password
                                / ),
                  ],
  },
};
