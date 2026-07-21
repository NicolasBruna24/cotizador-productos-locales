import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cotizador_de_productos_locales/product_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Reemplaza estos valores con los de tu proyecto en Supabase
  await Supabase.initialize(
    url: 'https://glxvtiemjzqlmdiytmow.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdseHZ0aWVtanpxbG1kaXl0bW93Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0MDEwODUsImV4cCI6MjA5MDk3NzA4NX0.HTw92i3vpxBFwjhnzKXBC6VBqtIR03D5SukhpcYlh50',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cotizador Local',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const ProductListScreen(),
    );
  }
}