defmodule MalanWeb.JsonRenderingTest do
  use ExUnit.Case, async: true

  alias Ecto.Association.NotLoaded

  alias Malan.Accounts.{
    Address,
    Log,
    PhoneNumber,
    Preference,
    Session,
    SessionExtension,
    User
  }

  alias Malan.Accounts.Log.{Type, Verb}
  alias Malan.Accounts.User.{PrivacyPolicyAcceptEvent, TosAcceptEvent}

  alias MalanWeb.{
    AddressJSON,
    LogJSON,
    PhoneNumberJSON,
    PreferencesJSON,
    PrivacyPolicyAcceptEventJSON,
    SessionExtensionJSON,
    SessionJSON,
    TosAcceptEventJSON,
    UserJSON
  }

  describe "address json" do
    test "renders indexes and standalone address entries" do
      address = %Address{
        id: "addr-1",
        user_id: "user-1",
        primary: true,
        verified_at: ~U[2023-01-01 00:00:00Z],
        name: "Home",
        line_1: "123 Main St",
        line_2: "Apt 4",
        country: "US",
        city: "Springfield",
        state: "IL",
        postal: "62701"
      }

      expected = %{
        id: "addr-1",
        user_id: "user-1",
        primary: true,
        verified_at: ~U[2023-01-01 00:00:00Z],
        name: "Home",
        line_1: "123 Main St",
        line_2: "Apt 4",
        country: "US",
        city: "Springfield",
        state: "IL",
        postal: "62701"
      }

      assert %{ok: true, data: [^expected]} = AddressJSON.index(%{addresses: [address]})
      assert %{ok: true, data: ^expected} = AddressJSON.show(%{address: address})
      assert AddressJSON.address(address) == expected
    end
  end

  describe "phone number json" do
    test "renders lists and standalone phone numbers" do
      phone = %PhoneNumber{
        id: "phone-1",
        user_id: "user-1",
        primary: false,
        number: "5551234567",
        verified_at: ~U[2023-01-02 00:00:00Z]
      }

      expected = %{
        id: "phone-1",
        user_id: "user-1",
        primary: false,
        number: "5551234567",
        verified_at: ~U[2023-01-02 00:00:00Z]
      }

      assert %{ok: true, data: [^expected]} = PhoneNumberJSON.index(%{phone_numbers: [phone]})
      assert %{ok: true, data: ^expected} = PhoneNumberJSON.show(%{phone_number: phone})
      assert PhoneNumberJSON.phone_number(phone) == expected
    end
  end

  describe "log json" do
    test "renders log entries with verb and type labels" do
      log = %Log{
        id: "log-1",
        success: true,
        type_enum: Type.to_i("users"),
        verb_enum: Verb.to_i("POST"),
        when: ~U[2023-01-03 00:00:00Z],
        what: "Created something",
        who: "user-1",
        user_id: "user-1",
        session_id: "session-1"
      }

      assert %{ok: true, data: [rendered]} = LogJSON.index(%{logs: [log]})
      assert rendered[:type] == "users"
      assert rendered[:verb] == "POST"
      assert rendered[:id] == "log-1"
      assert %{ok: true, data: rendered_show} = LogJSON.show(%{log: log})
      assert rendered_show == rendered
    end
  end

  describe "preferences json" do
    test "renders preferences struct" do
      preferences = %Preference{
        theme: "dark",
        display_name_pref: "first_name",
        display_middle_initial_only: true
      }

      assert PreferencesJSON.preferences(preferences) == %{
               theme: "dark",
               display_name_pref: "first_name",
               display_middle_initial_only: true
             }

      assert PreferencesJSON.preferences(%{preferences: preferences}) == %{
               theme: "dark",
               display_name_pref: "first_name",
               display_middle_initial_only: true
             }

      assert PreferencesJSON.preferences(nil) == nil
    end
  end

  describe "policy and tos event json" do
    test "renders embedded acceptance events" do
      tos_event = %TosAcceptEvent{
        accept: true,
        tos_version: 7,
        timestamp: ~U[2023-01-04 00:00:00Z]
      }

      pp_event = %PrivacyPolicyAcceptEvent{
        accept: false,
        privacy_policy_version: 3,
        timestamp: ~U[2023-01-05 00:00:00Z]
      }

      assert TosAcceptEventJSON.tos_accept_event(tos_event) == %{
               accept: true,
               tos_version: 7,
               timestamp: ~U[2023-01-04 00:00:00Z]
             }

      assert PrivacyPolicyAcceptEventJSON.privacy_policy_accept_event(pp_event) == %{
               accept: false,
               privacy_policy_version: 3,
               timestamp: ~U[2023-01-05 00:00:00Z]
             }
    end
  end

  describe "session extension json" do
    test "renders index and show payloads" do
      extension = %SessionExtension{
        id: "se-1",
        old_expires_at: ~U[2023-01-06 00:00:00Z],
        new_expires_at: ~U[2023-01-06 00:01:00Z],
        extended_by_seconds: 60,
        extended_by_session: "session-1",
        extended_by_user: "user-1",
        session_id: "session-1",
        user_id: "user-1"
      }

      assert %{
               ok: true,
               code: 200,
               page_num: 0,
               page_size: 10,
               data: [rendered]
             } =
               SessionExtensionJSON.index(%{
                 code: 200,
                 page_num: 0,
                 page_size: 10,
                 session_extensions: [extension]
               })

      assert rendered[:id] == "se-1"

      assert %{ok: true, code: 200, data: ^rendered} =
               SessionExtensionJSON.show(%{code: 200, session_extension: extension})
    end
  end

  describe "session json" do
    test "renders session payloads and omits nil tokens" do
      session = %Session{
        id: "session-1",
        user_id: "user-1",
        api_token: nil,
        expires_at: ~U[2023-01-07 00:00:00Z],
        authenticated_at: ~U[2023-01-06 23:00:00Z],
        revoked_at: nil,
        ip_address: "127.0.0.1",
        valid_only_for_ip: false,
        valid_only_for_approved_ips: false,
        location: "earth",
        extendable_until: ~U[2023-01-08 00:00:00Z],
        max_extension_secs: 300
      }

      assert %{ok: true, code: 200, data: [rendered]} =
               SessionJSON.index(%{code: 200, sessions: [session]})

      refute Map.has_key?(rendered, :api_token)
      assert %{ok: true, code: 200, data: rendered_show} =
               SessionJSON.show(%{code: 200, session: session})
      assert rendered_show == rendered

      assert %{
               ok: true,
               code: 200,
               data: %{status: true, num_revoked: 5, message: "Successfully revoked 5 session"}
             } =
               SessionJSON.delete_all(%{code: 200, num_revoked: 5})
    end
  end

  describe "user json" do
    test "renders minimal user when associations are not loaded" do
      not_loaded = %NotLoaded{__field__: :addresses, __owner__: User, __cardinality__: :many}

      user = %User{
        id: "user-1",
        username: "tester",
        first_name: "Test",
        last_name: "User",
        nick_name: nil,
        password: nil,
        email: "tester@example.com",
        email_verified: true,
        birthday: ~D[1990-01-01],
        addresses: not_loaded,
        phone_numbers: not_loaded,
        preferences: %NotLoaded{__field__: :preferences, __owner__: User, __cardinality__: :one},
        tos_accept_events: [],
        privacy_policy_accept_events: [],
        roles: ["user"],
        custom_attrs: %{},
        approved_ips: []
      }

      assert %{ok: true, code: 200, data: data} = UserJSON.show(%{code: 200, user: user})
      refute Map.has_key?(data, :addresses)
      refute Map.has_key?(data, :phone_numbers)
      assert data[:preferences] == nil
    end

    test "renders full user with loaded associations" do
      address = %Address{
        id: "addr-1",
        user_id: "user-2",
        primary: true,
        verified_at: nil,
        name: "Main",
        line_1: "456 Oak",
        line_2: nil,
        country: "US",
        city: "Metropolis",
        state: "NY",
        postal: "10001"
      }

      phone = %PhoneNumber{
        id: "phone-2",
        user_id: "user-2",
        primary: false,
        number: "5557654321",
        verified_at: nil
      }

      preferences = %Preference{
        theme: "light",
        display_name_pref: "full_name",
        display_middle_initial_only: false
      }

      tos_event = %TosAcceptEvent{
        accept: true,
        tos_version: 2,
        timestamp: ~U[2023-01-08 00:00:00Z]
      }

      pp_event = %PrivacyPolicyAcceptEvent{
        accept: true,
        privacy_policy_version: 1,
        timestamp: ~U[2023-01-09 00:00:00Z]
      }

      user = %User{
        id: "user-2",
        username: "complete",
        first_name: "Full",
        last_name: "Account",
        nick_name: "FA",
        password: "secret",
        email: "full@example.com",
        email_verified: true,
        birthday: ~D[1995-05-05],
        addresses: [address],
        phone_numbers: [phone],
        preferences: preferences,
        tos_accept_events: [tos_event],
        privacy_policy_accept_events: [pp_event],
        roles: ["user", "admin"],
        custom_attrs: %{"key" => "value"},
        locked_at: nil,
        locked_by: nil,
        approved_ips: ["1.2.3.4"]
      }

      assert %{ok: true, code: 200, data: data} = UserJSON.show(%{code: 200, user: user})
      assert [%{id: "addr-1"}] = data[:addresses]
      assert [%{id: "phone-2"}] = data[:phone_numbers]
      assert %{
               theme: "light",
               display_name_pref: "full_name",
               display_middle_initial_only: false
             } = data[:preferences]

      assert [%{tos_version: 2}] = data[:tos_accept_events]
      assert [%{privacy_policy_version: 1}] = data[:privacy_policy_accept_events]

      assert %{ok: true, code: 200, page_num: 0, page_size: 10, data: [index_data]} =
               UserJSON.index(%{code: 200, users: [user], page_num: 0, page_size: 10})

      assert index_data[:id] == data[:id]
      assert index_data[:username] == data[:username]
      refute Map.has_key?(index_data, :addresses)
      refute Map.has_key?(index_data, :phone_numbers)

      assert %{ok: true, code: 200, data: %{password_reset_token: "tok"}} =
               UserJSON.password_reset(%{
                 code: 200,
                 password_reset_token: "tok",
                 password_reset_token_expires_at: ~U[2023-01-10 00:00:00Z]
               })
    end
  end
end
