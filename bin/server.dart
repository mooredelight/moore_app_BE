import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:postgres/postgres.dart';
import 'package:dotenv/dotenv.dart' as dotenv;

// CORS middleware to allow cross-origin requests
Middleware corsMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, X-Auth-Token, Authorization',
          'Access-Control-Allow-Credentials': 'true',
        });
      }
      
      final response = await innerHandler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, X-Auth-Token, Authorization',
        'Access-Control-Allow-Credentials': 'true',
        ...response.headers,
      });
    };
  };
}

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

  // Home route
  router.get('/', (Request request) async {
    return Response.ok(jsonEncode({'message': 'Moore Delight Dart Server is running!'}), headers: {'Content-Type': 'application/json'});
  });

  // GET all products
  router.get('/products', (Request request) async {
    final results = await db.query('SELECT * FROM products');
    final products = results.map((row) {
      return {
        'id': row[0],
        'name': row[1],
        'description': row[2],
        'price': row[3],
        'image_url': row[4],
      };
    }).toList();
    return Response.ok(jsonEncode(products), headers: {'Content-Type': 'application/json'});
  });

  // POST new product
  router.post('/products', (Request request) async {
    final payload = await request.readAsString();
    final data = jsonDecode(payload);

    await db.query(
      'INSERT INTO products (name, description, price, image_url) VALUES (@name, @description, @price, @image_url)',
      substitutionValues: {
        'name': data['name'],
        'description': data['description'],
        'price': data['price'],
        'image_url': data['image_url'],
      },
    );
    return Response.ok(jsonEncode({'message': 'Product created'}), headers: {'Content-Type': 'application/json'});
  });

  // GET product by id
  router.get('/products/<id>', (Request request, String id) async {
    final results = await db.query('SELECT * FROM products WHERE id = @id', substitutionValues: {'id': int.parse(id)});
    if (results.isEmpty) {
      return Response.notFound(jsonEncode({'error': 'Product not found'}), headers: {'Content-Type': 'application/json'});
    }
    final row = results.first;
    final product = {
      'id': row[0],
      'name': row[1],
      'description': row[2],
      'price': row[3],
      'image_url': row[4],
    };
    return Response.ok(jsonEncode(product), headers: {'Content-Type': 'application/json'});
  });

  // GET all users
  router.get('/users', (Request request) async {
    final results = await db.query('SELECT * FROM users');
    final users = results.map((row) {
      return {
        'id': row[0],
        'name': row[1],
        'email': row[2],
        // Add other fields as needed
      };
    }).toList();
    return Response.ok(jsonEncode(users), headers: {'Content-Type': 'application/json'});
  });

  // POST new user
  router.post('/users', (Request request) async {
    final payload = await request.readAsString();
    final data = jsonDecode(payload);

    await db.query(
      'INSERT INTO users (name, email) VALUES (@name, @email)',
      substitutionValues: {
        'name': data['name'],
        'email': data['email'],
      },
    );
    return Response.ok(jsonEncode({'message': 'User created'}), headers: {'Content-Type': 'application/json'});
  });

  // GET user by id
  router.get('/users/<id>', (Request request, String id) async {
    final results = await db.query('SELECT * FROM users WHERE id = @id', substitutionValues: {'id': int.parse(id)});
    if (results.isEmpty) {
      return Response.notFound(jsonEncode({'error': 'User not found'}), headers: {'Content-Type': 'application/json'});
    }
    final row = results.first;
    final user = {
      'id': row[0],
      'name': row[1],
      'email': row[2],
      // Add other fields as needed
    };
    return Response.ok(jsonEncode(user), headers: {'Content-Type': 'application/json'});
  });

  // GET user by email
  router.get('/users/email/<email>', (Request request, String email) async {
    final results = await db.query('SELECT * FROM users WHERE email = @email', substitutionValues: {'email': email});
    if (results.isEmpty) {
      return Response.notFound(jsonEncode({'error': 'User not found'}), headers: {'Content-Type': 'application/json'});
    }
    final row = results.first;
    final user = {
      'id': row[0],
      'name': row[1],
      'email': row[2],
      // Add other fields as needed
    };
    return Response.ok(jsonEncode(user), headers: {'Content-Type': 'application/json'});
  });

  final handler = Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware()) // Add CORS middleware
      .addHandler(router.call);

  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, InternetAddress.anyIPv4, port);
  print('Server listening on port ${server.port}');
}