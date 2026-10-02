/// Contenitore per le credenziali inserite nella schermata di login.
///
/// Niente equivalente "response": per il login basta sapere se
/// `AuthProvider.signIn()` ha avuto successo o meno, non serve un modello
/// dedicato a rappresentare il risultato.
class LoginData {
  String email = '';
  String password = '';
}