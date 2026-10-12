#include "passkey_capability.h"
#include <windows.h>
#include <winbio.h>
#include <vector>

bool HasEnrolledBiometrics() {
  HANDLE token = nullptr;
  if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return false;
  DWORD size = 0;
  GetTokenInformation(token, TokenUser, nullptr, 0, &size);
  if (size == 0 || size > 65536) { CloseHandle(token); return false; }
  std::vector<BYTE> buffer(size);
  const bool read = GetTokenInformation(token, TokenUser, buffer.data(), size, &size) != FALSE;
  CloseHandle(token);
  if (!read) return false;
  const auto user = reinterpret_cast<TOKEN_USER*>(buffer.data());
  if (!IsValidSid(user->User.Sid)) return false;
  WINBIO_IDENTITY identity = {};
  identity.Type = WINBIO_ID_TYPE_SID;
  identity.Value.AccountSid.Size = GetLengthSid(user->User.Sid);
  if (identity.Value.AccountSid.Size > sizeof(identity.Value.AccountSid.Data) ||
      !CopySid(static_cast<DWORD>(sizeof(identity.Value.AccountSid.Data)), identity.Value.AccountSid.Data, user->User.Sid)) return false;
  WINBIO_BIOMETRIC_TYPE factors = WINBIO_NO_TYPE_AVAILABLE;
  // Unlike Windows Hello availability, this never treats a PIN as a biometric.
  return SUCCEEDED(WinBioGetEnrolledFactors(&identity, &factors)) &&
      factors != WINBIO_NO_TYPE_AVAILABLE;
}
