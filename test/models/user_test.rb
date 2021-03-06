require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'actions are performed on user create' do
    user = build(:user, user_opts)

    SlackJobs::InviterJob.expects(:perform_later).with(user_opts[:email])
    AddUserToAirtablesJob.expects(:perform_later).with(user)
    AddUserToSendGridJob.expects(:perform_later).with(user)

    assert_difference('User.count') { user.save }
  end

  test 'must have a valid email' do
    refute User.new(email: 'bogusemail', password: 'password', zip: '97201').valid?
    assert User.new(email: 'goodemail@example.com', password: 'password', zip: '97201').valid?
  end

  test 'email must be unique' do
    test_email = 'test@example.com'
    assert create(:user, email: test_email)
    refute User.new(email: test_email).valid?
  end

  test 'email is downcased on create' do
    u = create(:user, email: 'NEW_EMAIL@exaMple.cOm')
    assert_equal 'new_email@example.com', u.email
  end

  test 'email is downcased after update' do
    u = create(:user, email: 'UPDATE_EMAIL@exaMple.cOm')
    u.update!(email: 'UPDATE_EMAIL@exaMple.cOm')
    assert_equal 'update_email@example.com', u.email
  end

  test 'doesnt geocode until we save' do
    u = build(:user, latitude: nil, longitude: nil)
    assert u.valid?

    u.save
    assert_equal 45.505603, u.latitude
    assert_equal -122.6882145, u.longitude
  end

  test 'accepts non-us zipcodes (UK)' do
    u = build(:user, latitude: nil, longitude: nil, zip: nil)

    u.update_attributes(zip: 'HP2 4HG')
    assert_equal 51.75592890000001, u.latitude
    assert_equal -0.4447103, u.longitude
  end

  test 'longitude and longitude are nil for unknown zipcodes' do
    u = build(:user, latitude: nil, longitude: nil, zip: nil)

    u.update_attributes(zip: 'bad zip code')
    assert_equal nil, u.latitude
    assert_equal nil, u.longitude
  end

  test 'updates geocode after update' do
    u = build(:user, latitude: 40.7143528, longitude: -74.0059731)

    u.update_attributes(zip: '80203')
    assert_equal 39.7312095, u.latitude
    assert_equal -104.9826965, u.longitude
    assert_equal 'CO', u.state
  end

  test 'only geocodes if zip is updated' do
    u = build(:user, latitude: 1, longitude: 1, zip: '97201')
    u.stubs(:zip_changed?).returns(false)
    u.save

    u.update_attributes(email: 'updated_email@example.com')
    assert_equal 1, u.latitude
    assert_equal 1, u.longitude
    assert_equal u.zip, '97201'

    u.stubs(:zip_changed?).returns(true)
    u.update_attributes(zip: '80203')
    assert_equal 39.7312095, u.latitude
    assert_equal -104.9826965, u.longitude
    assert_equal 'CO', u.state
  end

  def user_opts
    { email: 'create_test@example.com', zip: '11772', password: 'password', password_confirmation: 'password' }
  end

  test '.count_by_zip returns a count of all users within the passed in zip code(s)' do
    tom = create :user, zip: '80112'
    sam = create :user, zip: '80126'
    bob = create :user, zip: '80126'

    results = User.count_by_zip '80126'
    assert_equal 2, results

    results = User.count_by_zip '80126, 80112'
    assert_equal 3, results

    results = User.count_by_zip ''
    assert_equal 0, results
  end

  test '.count_by_location returns a count of all users within the passed in city, or latitude/longitude, and radius from that location' do
    tom = create :user, zip: '78705'
    sam = create :user, zip: '78756'
    bob = create :user, zip: '83704'

    tom.update latitude: 30.285648, longitude: -97.742052
    sam.update latitude: 30.312601, longitude: -97.738591
    bob.update latitude: 43.606690, longitude: -116.282246

    results = User.count_by_location [30.285648, -97.742052]
    assert_equal 2, results

    results = User.count_by_location [43.606690, -116.282246]
    assert_equal 1, results

    results = User.count_by_location ''
    assert_equal 0, results
  end

  test 'it returns a users full name' do
    assert_equal 'first last', User.new(first_name: 'first', last_name: 'last').name
  end

  test '.count_by_state returns a count of all users within the passed in state(s)' do
    tom = create :user
    sam = create :user
    bob = create :user

    tom.update_columns state: 'TX'
    sam.update_columns state: 'TX'
    bob.update_columns state: 'CA'

    results = User.count_by_state 'TX'
    assert_equal 2, results

    results = User.count_by_state 'TX, CA'
    assert_equal 3, results

    results = User.count_by_state ''
    assert_equal 0, results
  end

  test 'VALID_EMAIL regex ensures valid formatting' do
    # valid email formats
    assert "john@gmail.com" =~ User::VALID_EMAIL
    assert "j@example.com" =~ User::VALID_EMAIL
    assert "jack@anything.io" =~ User::VALID_EMAIL
    assert "jack@anything.org" =~ User::VALID_EMAIL
    assert "jack@anything.net" =~ User::VALID_EMAIL
    assert "jack@anything.whatever" =~ User::VALID_EMAIL

    # invalid email formats
    refute "johngmail.com" =~ User::VALID_EMAIL
    refute "john#gmail.com" =~ User::VALID_EMAIL
    refute "john@gmail" =~ User::VALID_EMAIL
    refute "@example.com" =~ User::VALID_EMAIL
  end
end
