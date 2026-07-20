defmodule MalanWeb.TotpJSON do
  def show(%{code: code, status: status}) do
    %{
      ok: true,
      code: code,
      data: %{
        status: status.status,
        confirmed_at: status.confirmed_at,
        backup_codes_remaining: status.backup_codes_remaining
      }
    }
  end

  # Enrollment provisioning payload — disclosed exactly once, by the
  # password-gated POST. GET never renders this.
  def enrollment(%{code: code, enrollment: enrollment}) do
    %{
      ok: true,
      code: code,
      data: %{
        secret_base32: enrollment.secret_base32,
        otpauth_uri: enrollment.otpauth_uri,
        qr_code_svg: enrollment.qr_code_svg
      }
    }
  end

  # Backup-code plaintexts — returned once and never retrievable again
  def backup_codes(%{code: code, backup_codes: backup_codes}) do
    %{ok: true, code: code, data: %{backup_codes: backup_codes}}
  end
end
