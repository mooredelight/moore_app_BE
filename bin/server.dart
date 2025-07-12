import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart' as dotenv;

void main(List<String> args) async {
  final env = dotenv.DotEnv()..load();

  final db = PostgreSQLConnection(
    env['DB_HOST']!,
    int.parse(env['DB_PORT']!),
    env['DB_NAME']!,
    username: env['DB_USER'],
    password: env['DB_PASSWORD'],
    useSSL: true,
  );
  await db.open();

  final router = Router();

  router.get('/products', (Request request) async {
    final results = await db.query('SELECT * FROM products');
    final products = results.map((row) {
      return {
        'id': row[0],
        'name': row[1],
        'description': row[2],
        // Add other fields as needed
      };
    }).toList();
    return Response.ok(products.toString(), headers: {'Content-Type': 'application/json'});
  });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(router);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, InternetAddress.anyIPv4, port);
  print('Server listening on port ${server.port}');
}