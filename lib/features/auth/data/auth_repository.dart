class AuthRepository {
  Future<bool> login(String email, String password) async {
    // TODO: Implement JWT auth
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  Future<void> logout() async {
    // TODO: Clear token
  }

  Future<bool> checkSession() async {
    // TODO: Validate token
    return true;
  }
}
