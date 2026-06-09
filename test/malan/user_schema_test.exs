defmodule Malan.UserSchemaTest do
  use Malan.DataCase, async: true

  alias Malan.Accounts.User

  describe "users" do
    def validate_property(validation_func, key, value, valid, err_msg_regex \\ "") do
      changeset =
        Ecto.Changeset.cast(%User{}, %{key => value}, [key])
        |> validation_func.()

      assert changeset.valid? == valid

      case valid do
        false ->
          Map.get(errors_on(changeset), key)
          |> Enum.any?(fn x -> x =~ ~r/#{err_msg_regex}/ end)

        true ->
          true
      end
    end

    def validate_email(email, valid, err_msg_regex \\ "") do
      changeset =
        Ecto.Changeset.cast(%User{}, %{email: email}, [:email])
        |> User.validate_email()

      assert changeset.valid? == valid

      case valid do
        false ->
          assert errors_on(changeset).email
                 |> Enum.any?(fn x -> x =~ ~r/#{err_msg_regex}/ end)

        true ->
          true
      end
    end

    test "registration_changeset downcases email before validating" do
      changeset =
        User.registration_changeset(%User{}, %{
          username: "testuser",
          email: "First.Last+Tag@EXAMPLE.COM"
        })

      assert changeset.changes.email == "first.last+tag@example.com"
      refute Keyword.has_key?(changeset.errors, :email)
    end

    test "registration_changeset requires an email" do
      changeset = User.registration_changeset(%User{}, %{username: "testuser"})
      assert "can't be blank" in errors_on(changeset).email

      # cast converts "" to nil, so the required check (not format) rejects it
      changeset = User.registration_changeset(%User{}, %{username: "testuser", email: ""})
      assert "can't be blank" in errors_on(changeset).email
    end

    test "#validate_username minimum length" do
      for username <- ["h", "ab"] do
        changeset =
          Ecto.Changeset.cast(%User{}, %{username: username}, [:username])
          |> User.validate_username()

        assert changeset.valid? == false

        # too short is purely a length error, not a format error
        assert errors_on(changeset).username
               |> Enum.any?(fn x -> x =~ ~r/should be at least/ end)

        refute errors_on(changeset).username
               |> Enum.any?(fn x -> x =~ ~r/has invalid format/ end)
      end
    end

    test "#validate_username maximum length" do
      changeset =
        Ecto.Changeset.cast(%User{}, %{username: String.duplicate("A", 189)}, [:username])
        |> User.validate_username()

      assert changeset.valid? == false

      # too long is purely a length error, not a format error
      assert errors_on(changeset).username
             |> Enum.any?(fn x -> x =~ ~r/should be at most/ end)

      refute errors_on(changeset).username
             |> Enum.any?(fn x -> x =~ ~r/has invalid format/ end)
    end

    # All of these must be accepted by the username format validation.
    @valid_usernames [
      "bob",
      "bob123",
      "BoB",
      # full email addresses are usable as usernames
      "user@example.com",
      "hello-_=_+*&^world@example.com",
      # pipe is fine anywhere except the first character
      "bobl|o",
      # unlike emails, usernames have no dot-structure rules
      "first.last",
      ".bob",
      "bob..by",
      # every allowed special character at once
      "!#$%&'*+-./=?^_`{|}~",
      "a.b",
      # length is enforced by validate_length alone (3 to 188), so the
      # old format-level 89-char cap no longer applies
      String.duplicate("a", 89),
      String.duplicate("a", 90),
      String.duplicate("a", 188)
    ]

    # All of these must be rejected with "has invalid format".
    @invalid_usernames [
      # comma slipped through the old regex's accidental "+-/" range
      "bob,by",
      "abcdefg(h",
      "abc)defgh",
      "[bob]",
      "bob;by",
      ~s(bob"by),
      # whitespace anywhere, including trailing newline (the old regex's
      # $ anchor matched before a trailing newline)
      "bob by",
      "bobby\n",
      "bob\nby",
      "bob\t",
      # non-ASCII
      "böb"
    ]

    test "#validate_username accepts valid usernames" do
      for username <- @valid_usernames do
        changeset =
          Ecto.Changeset.cast(%User{}, %{username: username}, [:username])
          |> User.validate_username()

        assert changeset.valid?,
               "expected #{inspect(username)} to be valid, errors: #{inspect(changeset.errors)}"
      end
    end

    test "#validate_username rejects invalid usernames" do
      for username <- @invalid_usernames do
        changeset =
          Ecto.Changeset.cast(%User{}, %{username: username}, [:username])
          |> User.validate_username()

        refute changeset.valid?, "expected #{inspect(username)} to be rejected"

        assert Enum.any?(errors_on(changeset).username, &(&1 =~ "has invalid format")),
               "expected format error for #{inspect(username)}, errors: #{inspect(changeset.errors)}"
      end
    end

    # Our deleted_at prefix includes | so need to make sure that no usernames do
    test "#validate_username rejects usernames starting with |" do
      changeset =
        Ecto.Changeset.cast(%User{}, %{username: "bobl|o"}, [:username])
        |> User.validate_username()

      assert changeset.valid? == true

      changeset =
        Ecto.Changeset.cast(%User{}, %{username: "|boblo"}, [:username])
        |> User.validate_username()

      assert changeset.valid? == false

      assert errors_on(changeset).username
             |> Enum.any?(fn x -> x =~ ~r/has invalid format/ end)
    end

    # All of these must be accepted by the email format validation.
    @valid_emails [
      "bob@hotmail.com",
      "v@mx.co",
      "a@b.co",
      "bob.zemeckis-hello+world74@hotmail.com",
      "bob.1!#$%^&*@hotmail.seven.four.com",
      "gregory+clark@example.com",
      "first.middle.last@example.com",
      "user_name@example.com",
      "o'connor@example.com",
      # every RFC 5322 atext special character at once
      "!#$%&'*+-/=?^_`{|}~@example.com",
      "user/dept=sales@example.com",
      "1234567890@example.com",
      "user@123.com",
      "user@example.co.uk",
      "user@sub.sub2.sub3.example.com",
      "user@hyphen-ated.com",
      "user@example.museum",
      # IDN (punycode) domains and TLDs
      "user@xn--mnchen-3ya.de",
      "user@example.xn--p1ai",
      "user@xn----7sbb4ac0ad0be6cf.xn--p1ai",
      # changesets downcase before validating, but the format check
      # itself must not depend on that
      "USER@EXAMPLE.COM",
      "user@Beta.com",
      # boundaries: 64-char local part, 63-char label, many labels
      String.duplicate("a", 64) <> "@example.com",
      "user@" <> String.duplicate("a", 63) <> ".com",
      "user@" <> String.duplicate("a.", 30) <> "example.com"
    ]

    # All of these must be rejected with "has invalid format".
    @invalid_emails [
      # missing pieces / no TLD
      "plainaddress",
      "bob@hotmail",
      "user@localhost",
      "@example.com",
      "user@",
      "user@example.c",
      # TLD longer than 25 chars
      "bob@hotmail.com" <> String.duplicate("A", 25),
      # characters outside the allowed sets
      "bob(hello@hotmail.com",
      "boblo@hot^mail.com",
      # more than one @
      "bob@hello@hotmail.com",
      "user@@example.com",
      # invalid chars that the old regex accepted via accidental
      # character-class ranges (",", and ":;<=>?@/" in the domain)
      "foo,bar@example.com",
      "user@foo,bar.com",
      "user@exa:mple.com",
      "user@exa;mple.com",
      "user@a=b.com",
      "user@a?b.com",
      "user@a/b.com",
      "user@a_b.com",
      # dots must separate non-empty local-part atoms
      ".user@example.com",
      "user.@example.com",
      "us..er@example.com",
      # domain label structure
      "user@.example.com",
      "user@..com",
      "user@example..com",
      "user@example.com.",
      "user@-example.com",
      "user@example-.com",
      "user@foo.-bar.com",
      "user@foo-.bar.com",
      # TLDs are letters or punycode, never digits
      "user@example.123",
      "user@example.123abc",
      # punycode labels can't end with a hyphen
      "user@xn--abc-.com",
      "user@foo.xn--abc-",
      # length limits: local part max 64, label max 63, domain max 253
      String.duplicate("a", 65) <> "@example.com",
      "user@" <> String.duplicate("a", 64) <> ".com",
      "a@" <> String.duplicate("a234567890.", 23) <> "com",
      # whitespace anywhere, including trailing newline (the old regex's
      # $ anchor matched before a trailing newline)
      "user name@example.com",
      "user@exam ple.com",
      " user@example.com",
      "user@example.com ",
      "user@example.com\n",
      "user@example.com\nattacker@evil.com",
      "user@example.com\t",
      # non-ASCII: IDN domains must be submitted in punycode form
      "üser@example.com",
      "user@münchen.de",
      # RFC quoted local parts and domain literals are unsupported
      ~s("quoted"@example.com),
      ~s("user name"@example.com),
      "user@[192.168.1.1]"
    ]

    test "#validate_email accepts valid emails" do
      for email <- @valid_emails do
        changeset =
          Ecto.Changeset.cast(%User{}, %{email: email}, [:email])
          |> User.validate_email()

        assert changeset.valid?,
               "expected #{inspect(email)} to be valid, errors: #{inspect(changeset.errors)}"
      end
    end

    test "#validate_email rejects invalid emails" do
      for email <- @invalid_emails do
        changeset =
          Ecto.Changeset.cast(%User{}, %{email: email}, [:email])
          |> User.validate_email()

        refute changeset.valid?, "expected #{inspect(email)} to be rejected"

        assert Enum.any?(errors_on(changeset).email, &(&1 =~ "has invalid format")),
               "expected format error for #{inspect(email)}, errors: #{inspect(changeset.errors)}"
      end
    end

    # Our deleted_at prefix includes | so need to make sure that no emails do
    test "#validate_email reject emails starting with |" do
      validate_email("boblo@hotmail.com", true)
      validate_email("|boblo@hotmail.com", false, "has invalid format")
    end

    test "#validate_email minimum total length" do
      validate_email("a@b.c", false, "should be at least")
    end

    test "#validate_email maximum total length" do
      # 240 chars total while every other limit is respected (local part
      # 64, labels <= 63, domain <= 253), so only total length rejects it
      validate_email(
        String.duplicate("a", 64) <>
          "@" <>
          String.duplicate("b", 60) <>
          "." <> String.duplicate("c", 60) <> "." <> String.duplicate("d", 49) <> ".com",
        false,
        "should be at most"
      )
    end

    test "#validate_email max length 2" do
      validate_email(
        "#{String.duplicate("A", 201)}bob@hotmail.com",
        false,
        "should be at most"
      )
    end

    test "#validate_password invalid 1 because too short" do
      validate_property(
        fn cs -> User.validate_password(cs, []) end,
        :password,
        # "password1",
        "pass",
        false,
        "Should be at least"
      )
    end

    test "#validate_password valid 1" do
      validate_property(
        fn cs -> User.validate_password(cs, []) end,
        :password,
        "password10",
        true
      )
    end

    test "#validate_password respects configured minimum length" do
      # Test with default minimum length
      min_length =
        Application.get_env(:malan, Malan.Accounts.User)
        |> Keyword.fetch!(:min_password_length)

      # Should pass with min_length characters
      changeset6 =
        %User{}
        |> Ecto.Changeset.cast(%{password: String.duplicate("a", min_length)}, [:password])
        |> User.validate_password([])

      assert changeset6.valid? == true
      assert changeset6.changes.password_hash != nil

      # Should fail with min_length - 1 characters
      changeset5 =
        %User{}
        |> Ecto.Changeset.cast(%{password: String.duplicate("a", min_length - 1)}, [:password])
        |> User.validate_password([])

      assert changeset5.valid? == false
      errors = errors_on(changeset5)
      assert "should be at least #{min_length} character(s)" in errors[:password]

      # Test with MIN_PASSWORD_LENGTH=8
      # Mock the config to return 8
      original_config = Application.get_env(:malan, Malan.Accounts.User)

      Application.put_env(
        :malan,
        Malan.Accounts.User,
        Keyword.put(original_config, :min_password_length, 8)
      )

      # Should fail with 7 characters
      changeset7 =
        %User{}
        |> Ecto.Changeset.cast(%{password: "pass123"}, [:password])
        |> User.validate_password([])

      assert changeset7.valid? == false
      errors7 = errors_on(changeset7)
      assert "should be at least 8 character(s)" in errors7[:password]

      # Should pass with 8 characters
      changeset8 =
        %User{}
        |> Ecto.Changeset.cast(%{password: "pass1234"}, [:password])
        |> User.validate_password([])

      assert changeset8.valid? == true
      assert changeset8.changes.password_hash != nil

      # Should pass with more than 8 characters
      changeset10 =
        %User{}
        |> Ecto.Changeset.cast(%{password: "password10"}, [:password])
        |> User.validate_password([])

      assert changeset10.valid? == true
      assert changeset10.changes.password_hash != nil

      # Restore original config
      Application.put_env(:malan, Malan.Accounts.User, original_config)
    end

    test "#validate_password respects admin-set and admin-account minimum lengths" do
      original_config = Application.get_env(:malan, Malan.Accounts.User)

      Application.put_env(
        :malan,
        Malan.Accounts.User,
        original_config
        |> Keyword.put(:min_password_length, 8)
        |> Keyword.put(:admin_set_user_min_password_length, 6)
        |> Keyword.put(:admin_account_min_password_length, 12)
      )

      # Regular user self-set -> user minimum
      changeset7 =
        %User{roles: ["user"]}
        |> Ecto.Changeset.cast(%{password: "pass123"}, [:password])
        |> User.validate_password([])

      assert changeset7.valid? == false
      errors7 = errors_on(changeset7)
      assert "should be at least 8 character(s)" in errors7[:password]

      changeset8 =
        %User{roles: ["user"]}
        |> Ecto.Changeset.cast(%{password: "pass1234"}, [:password])
        |> User.validate_password([])

      assert changeset8.valid? == true

      # Admin sets regular user -> admin-set minimum
      changeset5_admin =
        %User{roles: ["user"]}
        |> Ecto.Changeset.cast(%{password: "pass1"}, [:password])
        |> User.validate_password(password_set_by_admin?: true)

      assert changeset5_admin.valid? == false
      errors5_admin = errors_on(changeset5_admin)
      assert "should be at least 6 character(s)" in errors5_admin[:password]

      changeset6_admin =
        %User{roles: ["user"]}
        |> Ecto.Changeset.cast(%{password: "pass12"}, [:password])
        |> User.validate_password(password_set_by_admin?: true)

      assert changeset6_admin.valid? == true

      # Admin account -> admin-account minimum applies
      changeset11_admin =
        %User{roles: ["admin"]}
        |> Ecto.Changeset.cast(%{password: "password111"}, [:password])
        |> User.validate_password([])

      assert changeset11_admin.valid? == false
      errors11_admin = errors_on(changeset11_admin)
      assert "should be at least 12 character(s)" in errors11_admin[:password]

      changeset12_admin =
        %User{roles: ["admin"]}
        |> Ecto.Changeset.cast(%{password: "password1111"}, [:password])
        |> User.validate_password([])

      assert changeset12_admin.valid? == true

      changeset11_admin_by_admin =
        %User{roles: ["admin"]}
        |> Ecto.Changeset.cast(%{password: "password111"}, [:password])
        |> User.validate_password(password_set_by_admin?: true)

      assert changeset11_admin_by_admin.valid? == false

      # Restore original config
      Application.put_env(:malan, Malan.Accounts.User, original_config)
    end

    test "accept/reject ToS can be accepted/rejected" do
      Enum.each([true, false], fn accept ->
        changeset =
          Ecto.Changeset.cast(%User{}, %{accept_tos: accept}, [:accept_tos])
          |> User.put_accept_tos()

        assert changeset.valid? == true
        assert changeset.valid? == true

        tos_cs =
          changeset.changes
          |> Map.get(:tos_accept_events)
          |> List.first()

        assert tos_cs.valid? == true
      end)
    end

    test "accept/reject ToS if not specified takes no action" do
      changeset =
        Ecto.Changeset.cast(%User{}, %{accept_tos: nil}, [:accept_tos])
        |> User.put_accept_tos()

      assert changeset.valid? == true
      assert changeset.changes == %{}
    end

    test "accept/reject ToS appends to the array" do
      changeset =
        Ecto.Changeset.cast(%User{}, %{accept_tos: true}, [:accept_tos])
        |> User.put_accept_tos()

      assert changeset.valid? == true
      assert changeset.valid? == true

      tos_cs =
        changeset.changes
        |> Map.get(:tos_accept_events)
        |> List.first()

      assert tos_cs.valid? == true
    end

    # test "roles must be valid" do
    #   changeset = Ecto.Changeset.cast(%User{}, %{roles: ["user"]}, [:roles])
    #               |> User.validate_roles()
    #   assert changeset.valid? == true

    #   changeset = Ecto.Changeset.cast(%User{}, %{roles: ["fake"]}, [:roles])
    #               |> User.validate_roles()
    #   assert changeset.valid? == false
    #   assert errors_on(changeset).roles
    #          |> Enum.any?(fn (x) -> x =~ ~r/has an invalid entry/ end)
    # end

    test "roles can be arbitrary" do
      changeset =
        Ecto.Changeset.cast(%User{}, %{roles: ["user"]}, [:roles])
        |> User.validate_roles()

      assert changeset.valid? == true

      changeset =
        Ecto.Changeset.cast(%User{}, %{roles: ["fake"]}, [:roles])
        |> User.validate_roles()

      assert changeset.valid? == true
    end

    test "#val_to_deleted_val/1" do
      assert User.val_to_deleted_val("userbinator") =~
               ~r/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}|userbinator/

      assert User.val_to_deleted_val("user@example.com") =~
               ~r/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}|user@example.com/
    end

    test "#deleted_val_to_val/1" do
      assert "billy" == User.deleted_val_to_val("64678b9f-aaaa-aaaa-aaaa-b1b0071e7603|billy")
      assert "madmax" == User.deleted_val_to_val("40a0fed2-539c-48a0-ac77-51967d5647e7|madmax")

      assert "userbinator" ==
               User.deleted_val_to_val("0a29dac0-2aa1-4e91-a061-5f59480d154d|userbinator")

      assert "user@example.com" ==
               User.deleted_val_to_val("0a29dac0-2aa1-4e91-a061-5f59480d154d|user@example.com")

      assert "user@example.com" ==
               User.deleted_val_to_val("64678b9f-adce-49f6-883e-b1b0071e7603|user@example.com")

      assert "user@example.com" ==
               User.deleted_val_to_val("40a0fed2-539c-48a0-ac77-51967d5647e7|user@example.com")
    end
  end

  describe "User.Sex" do
    test "#to_s" do
      assert nil == User.Sex.to_s(nil)
      assert "Male" == User.Sex.to_s(0)
      assert "Female" == User.Sex.to_s(1)
      assert "Other" == User.Sex.to_s(2)
      assert nil == User.Sex.to_s(3)
    end

    test "#to_i" do
      assert 0 == User.Sex.to_i("Male")
      assert 1 == User.Sex.to_i("Female")
      assert 2 == User.Sex.to_i("Other")
      assert nil == User.Sex.to_i("prefer_not")
      assert nil == User.Sex.to_i("fake")
    end

    test "#valid?" do
      assert true == User.Sex.valid?("Male")
      assert true == User.Sex.valid?("Female")
      assert true == User.Sex.valid?("Other")
      assert false == User.Sex.valid?("prefer_not")
      assert false == User.Sex.valid?("fake")

      assert false == User.Sex.valid?(-1)
      assert true == User.Sex.valid?(0)
      assert true == User.Sex.valid?(1)
      assert true == User.Sex.valid?(2)
      assert false == User.Sex.valid?(3)
      assert false == User.Sex.valid?(4)
    end
  end

  describe "User.Gender" do
    test "#to_s" do
      assert "Agender" == User.Gender.to_s(0)
      assert "Androgyne" == User.Gender.to_s(1)
      assert "Androgynes" == User.Gender.to_s(2)
      assert "Androgynous" == User.Gender.to_s(3)
      assert "Bigender" == User.Gender.to_s(4)
      assert "Cis" == User.Gender.to_s(5)
      assert "Cis Female" == User.Gender.to_s(6)
      assert "Cis Male" == User.Gender.to_s(7)
      assert "Cis Man" == User.Gender.to_s(8)
      assert "Cis Woman" == User.Gender.to_s(9)
      assert "Cisgender" == User.Gender.to_s(10)
      assert "Cisgender Female" == User.Gender.to_s(11)
      assert "Cisgender Male" == User.Gender.to_s(12)
      assert "Cisgender Man" == User.Gender.to_s(13)
      assert "Cisgender Woman" == User.Gender.to_s(14)
      assert "Female to Male" == User.Gender.to_s(15)
      assert "FTM" == User.Gender.to_s(16)
      assert "Gender Fluid" == User.Gender.to_s(17)
      assert "Gender Nonconforming" == User.Gender.to_s(18)
      assert "Gender Questioning" == User.Gender.to_s(19)
      assert "Gender Variant" == User.Gender.to_s(20)
      assert "Genderqueer" == User.Gender.to_s(21)
      assert "Intersex" == User.Gender.to_s(22)
      assert "Male to Female" == User.Gender.to_s(23)
      assert "MTF" == User.Gender.to_s(24)
      assert "Neither" == User.Gender.to_s(25)
      assert "Neutrois" == User.Gender.to_s(26)
      assert "Non-binary" == User.Gender.to_s(27)
      assert "Other" == User.Gender.to_s(28)
      assert "Pangender" == User.Gender.to_s(29)
      assert "Trans" == User.Gender.to_s(30)
      assert "Trans Female" == User.Gender.to_s(31)
      assert "Trans Male" == User.Gender.to_s(32)
      assert "Trans Man" == User.Gender.to_s(33)
      assert "Trans Person" == User.Gender.to_s(34)
      assert "Trans*Female" == User.Gender.to_s(35)
      assert "Trans*Male" == User.Gender.to_s(36)
      assert "Trans*Man" == User.Gender.to_s(37)
      assert "Trans*Person" == User.Gender.to_s(38)
      assert "Trans*Woman" == User.Gender.to_s(39)
      assert "Transexual" == User.Gender.to_s(40)
      assert "Transexual Female" == User.Gender.to_s(41)
      assert "Transexual Male" == User.Gender.to_s(42)
      assert "Transexual Man" == User.Gender.to_s(43)
      assert "Transexual Person" == User.Gender.to_s(44)
      assert "Transexual Woman" == User.Gender.to_s(45)
      assert "Transgender Female" == User.Gender.to_s(46)
      assert "Transgender Person" == User.Gender.to_s(47)
      assert "Transmasculine" == User.Gender.to_s(48)
      assert "Two-spirit" == User.Gender.to_s(49)
      assert "Male" == User.Gender.to_s(50)
      assert "Female" == User.Gender.to_s(51)
      assert nil == User.Gender.to_i("fake")
    end

    test "#to_i" do
      assert nil == User.Gender.to_i("fake")
      assert 0 == User.Gender.to_i("Agender")
      assert 1 == User.Gender.to_i("Androgyne")
      assert 2 == User.Gender.to_i("Androgynes")
      assert 3 == User.Gender.to_i("Androgynous")
      assert 4 == User.Gender.to_i("Bigender")
      assert 5 == User.Gender.to_i("Cis")
      assert 6 == User.Gender.to_i("Cis Female")
      assert 7 == User.Gender.to_i("Cis Male")
      assert 8 == User.Gender.to_i("Cis Man")
      assert 9 == User.Gender.to_i("Cis Woman")
      assert 10 == User.Gender.to_i("Cisgender")
      assert 11 == User.Gender.to_i("Cisgender Female")
      assert 12 == User.Gender.to_i("Cisgender Male")
      assert 13 == User.Gender.to_i("Cisgender Man")
      assert 14 == User.Gender.to_i("Cisgender Woman")
      assert 15 == User.Gender.to_i("Female to Male")
      assert 16 == User.Gender.to_i("FTM")
      assert 17 == User.Gender.to_i("Gender Fluid")
      assert 18 == User.Gender.to_i("Gender Nonconforming")
      assert 19 == User.Gender.to_i("Gender Questioning")
      assert 20 == User.Gender.to_i("Gender Variant")
      assert 21 == User.Gender.to_i("Genderqueer")
      assert 22 == User.Gender.to_i("Intersex")
      assert 23 == User.Gender.to_i("Male to Female")
      assert 24 == User.Gender.to_i("MTF")
      assert 25 == User.Gender.to_i("Neither")
      assert 26 == User.Gender.to_i("Neutrois")
      assert 27 == User.Gender.to_i("Non-binary")
      assert 28 == User.Gender.to_i("Other")
      assert 29 == User.Gender.to_i("Pangender")
      assert 30 == User.Gender.to_i("Trans")
      assert 31 == User.Gender.to_i("Trans Female")
      assert 32 == User.Gender.to_i("Trans Male")
      assert 33 == User.Gender.to_i("Trans Man")
      assert 34 == User.Gender.to_i("Trans Person")
      assert 35 == User.Gender.to_i("Trans*Female")
      assert 36 == User.Gender.to_i("Trans*Male")
      assert 37 == User.Gender.to_i("Trans*Man")
      assert 38 == User.Gender.to_i("Trans*Person")
      assert 39 == User.Gender.to_i("Trans*Woman")
      assert 40 == User.Gender.to_i("Transexual")
      assert 41 == User.Gender.to_i("Transexual Female")
      assert 42 == User.Gender.to_i("Transexual Male")
      assert 43 == User.Gender.to_i("Transexual Man")
      assert 44 == User.Gender.to_i("Transexual Person")
      assert 45 == User.Gender.to_i("Transexual Woman")
      assert 46 == User.Gender.to_i("Transgender Female")
      assert 47 == User.Gender.to_i("Transgender Person")
      assert 48 == User.Gender.to_i("Transmasculine")
      assert 49 == User.Gender.to_i("Two-spirit")
      assert 50 == User.Gender.to_i("Male")
      assert 51 == User.Gender.to_i("Female")
      # spot check some normalized
      assert 47 == User.Gender.to_i("transgender person")
      assert 48 == User.Gender.to_i("transmasculine")
      assert 49 == User.Gender.to_i("two-spirit")
      assert 50 == User.Gender.to_i("male")
      assert 51 == User.Gender.to_i("female")
    end

    test "#valid?" do
      assert true == User.Gender.valid?("male")
      assert true == User.Gender.valid?("female")
      assert true == User.Gender.valid?("other")
      assert false == User.Gender.valid?("fake")

      assert false == User.Gender.valid?(-1)
      assert true == User.Gender.valid?(0)
      assert true == User.Gender.valid?(1)
      assert true == User.Gender.valid?(2)
      assert true == User.Gender.valid?(3)
      assert false == User.Gender.valid?(55)
    end

    test "#normalize" do
      assert "two-spirit" == User.Gender.normalize("Two-spirit")
      assert "trans*woman" == User.Gender.normalize("Trans*Woman")
    end
  end

  describe "User.Ethnicity" do
    test "#to_s" do
      assert nil == User.Ethnicity.to_s(nil)
      assert "Hispanic or Latinx" == User.Ethnicity.to_s(0)
      assert "Not Hispanic or Latinx" == User.Ethnicity.to_s(1)
      assert nil == User.Ethnicity.to_s(4)
    end

    test "#to_i" do
      assert 0 == User.Ethnicity.to_i("Hispanic or Latinx")
      assert 1 == User.Ethnicity.to_i("Not Hispanic or Latinx")
      assert nil == User.Ethnicity.to_i("fake")
    end

    test "#valid?" do
      assert true == User.Ethnicity.valid?("Hispanic or Latinx")
      assert true == User.Ethnicity.valid?("Not Hispanic or Latinx")
      assert false == User.Ethnicity.valid?("fake")

      assert false == User.Ethnicity.valid?(-1)
      assert true == User.Ethnicity.valid?(0)
      assert true == User.Ethnicity.valid?(1)
      assert false == User.Ethnicity.valid?(2)
    end
  end

  describe "User.Race" do
    defp races_to_cs(races), do: %Ecto.Changeset{changes: %{race: races}}

    test "#all_races_valid?/1" do
      assert false == User.all_races_valid?(races_to_cs(["one", "two"]))
      assert true == User.all_races_valid?(races_to_cs(["Black or African American", "White"]))
      assert true == User.all_races_valid?(races_to_cs(["Asian"]))

      assert true ==
               User.all_races_valid?(
                 races_to_cs([
                   "American Indian or Alaska Native",
                   "Native Hawaiian or Other Pacific Islander"
                 ])
               )

      assert true == User.all_races_valid?(races_to_cs([]))
      assert false == User.all_races_valid?(races_to_cs(["Asian", "one"]))
    end

    test "#race_list/1" do
      assert [1, 4] == User.race_list(races_to_cs(["Asian", "White"]))
      assert [1, 4] == User.race_list(races_to_cs(["asian", "white"]))

      assert [0, 1, 2, 3, 4] =
               User.race_list(
                 races_to_cs([
                   "American Indian or Alaska Native",
                   "Asian",
                   "Black or African American",
                   "Native Hawaiian or Other Pacific Islander",
                   "white"
                 ])
               )
    end
  end
end
