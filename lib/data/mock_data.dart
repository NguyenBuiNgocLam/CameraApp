import 'package:flutter/material.dart';

import '../models/quiz_models.dart';
import '../models/vocabulary_item.dart';

class MockData {
  const MockData._();

  static final now = DateTime(2026, 1, 1);

  static final vocabulary = [
    VocabularyItem(
      id: 'mock-camera',
      userId: 'mock-user',
      word: 'Camera',
      meaningVi: 'Máy ảnh',
      phonetic: '/ˈkæmərə/',
      partOfSpeech: 'Noun',
      exampleEn: 'I use a camera to take photos.',
      exampleVi: 'Tôi dùng máy ảnh để chụp ảnh.',
      icon: Icons.photo_camera_rounded,
      isFavorite: true,
      createdAt: now,
      updatedAt: now,
    ),
    VocabularyItem(
      id: 'mock-bottle',
      userId: 'mock-user',
      word: 'Bottle',
      meaningVi: 'Cái chai',
      phonetic: '/ˈbɑːtl/',
      partOfSpeech: 'Noun',
      exampleEn: 'There is a water bottle on the table.',
      exampleVi: 'Có một chai nước trên bàn.',
      icon: Icons.water_drop_rounded,
      isFavorite: true,
      createdAt: now,
      updatedAt: now,
    ),
    VocabularyItem(
      id: 'mock-laptop',
      userId: 'mock-user',
      word: 'Laptop',
      meaningVi: 'Máy tính xách tay',
      phonetic: '/ˈlæptɑːp/',
      partOfSpeech: 'Noun',
      exampleEn: 'My laptop helps me study English online.',
      exampleVi: 'Máy tính xách tay giúp tôi học tiếng Anh trực tuyến.',
      icon: Icons.laptop_mac_rounded,
      createdAt: now,
      updatedAt: now,
    ),
    VocabularyItem(
      id: 'mock-backpack',
      userId: 'mock-user',
      word: 'Backpack',
      meaningVi: 'Ba lô',
      phonetic: '/ˈbækpæk/',
      partOfSpeech: 'Noun',
      exampleEn: 'She carries books in her backpack.',
      exampleVi: 'Cô ấy mang sách trong ba lô.',
      icon: Icons.backpack_rounded,
      createdAt: now,
      updatedAt: now,
    ),
    VocabularyItem(
      id: 'mock-headphones',
      userId: 'mock-user',
      word: 'Headphones',
      meaningVi: 'Tai nghe',
      phonetic: '/ˈhedfoʊnz/',
      partOfSpeech: 'Noun',
      exampleEn: 'He listens to podcasts with headphones.',
      exampleVi: 'Anh ấy nghe podcast bằng tai nghe.',
      icon: Icons.headphones_rounded,
      isFavorite: true,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  static const quizQuestions = [
    QuizQuestion(
      question: 'What is the English word for "Máy ảnh"?',
      options: ['Camera', 'Bottle', 'Laptop', 'Backpack'],
      correctIndex: 0,
    ),
    QuizQuestion(
      question: 'Choose the Vietnamese meaning of "Bottle".',
      options: ['Tai nghe', 'Cái chai', 'Ba lô', 'Máy ảnh'],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'Which word matches /ˈlæptɑːp/?',
      options: ['Camera', 'Headphones', 'Laptop', 'Bottle'],
      correctIndex: 2,
    ),
    QuizQuestion(
      question: 'Complete: She carries books in her ____.',
      options: ['camera', 'backpack', 'bottle', 'headphones'],
      correctIndex: 1,
    ),
    QuizQuestion(
      question: 'What is "Tai nghe" in English?',
      options: ['Laptop', 'Backpack', 'Headphones', 'Camera'],
      correctIndex: 2,
    ),
  ];
}
