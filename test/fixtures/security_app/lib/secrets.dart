const accessKey = 'AKIAIOSFODNN7EXAMPLE';
const apiKey = 'supersecretvalue123';
const clientSecret = 'clientsecretvalue123';

void leak(String password) {
  print(password);
}

const endpoint = 'http://insecure.example';

void install(dynamic client) {
  client.badCertificateCallback = (cert, host, port) => true;
}
