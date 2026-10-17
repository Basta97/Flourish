import 'package:flourish/core/detection/category_resolver.dart';
import 'package:flourish/core/detection/message_splitter.dart';
import 'package:flourish/data/database/database.dart' show Category;
import 'package:flutter_test/flutter_test.dart';

Category cat(int id, String name, [String type = 'expense']) => Category(
  id: id,
  name: name,
  icon: 'more_horiz',
  color: 0,
  type: type,
  isDefault: true,
  sortOrder: id,
);

void main() {
  final categories = [
    cat(1, 'Salary', 'income'),
    cat(2, 'Food & Drinks'),
    cat(3, 'Transport'),
    cat(4, 'Shopping'),
    cat(9, 'Other'),
  ];

  group('CategoryResolver', () {
    test('concepts map to existing categories before proposing', () {
      final r = CategoryResolver(categories);
      expect(
        r.fromConcept(const CategoryQuery(type: 'expense', merchant: 'Spinneys')).categoryId,
        2,
        reason: 'groceries → Food & Drinks',
      );
      expect(
        r.fromConcept(const CategoryQuery(type: 'expense', merchant: 'Seif Pharmacy')).proposed?.name,
        'Health',
      );
      expect(
        CategoryResolver(categories, allowNew: false)
            .fromConcept(const CategoryQuery(type: 'expense', merchant: 'Seif Pharmacy'))
            .found,
        isFalse,
      );
    });

    test('"Apple Pay" alone is not shopping; Metro Market is groceries', () {
      final r = CategoryResolver(categories);
      expect(
        r.fromConcept(const CategoryQuery(type: 'expense', text: 'Apple Pay purchase')).found,
        isFalse,
      );
      expect(
        r.fromConcept(const CategoryQuery(type: 'expense', merchant: 'Metro Market')).categoryId,
        2,
      );
    });

    test('AI proposals merge into similar names and respect type', () {
      final r = CategoryResolver(categories);
      expect(
        r.fromAi(const CategoryQuery(
          type: 'expense',
          aiProposed: ProposedCategory(
            name: 'shoppings',
            type: 'expense',
            icon: 'shopping_bag',
            colorIndex: 0,
          ),
        )).categoryId,
        4,
      );
      expect(
        r.fromAi(const CategoryQuery(type: 'expense', aiCategoryId: 1)).found,
        isFalse,
        reason: 'Salary is an income category',
      );
    });

    test('similarity', () {
      expect(CategoryResolver.similarity('food', 'food'), 1);
      expect(CategoryResolver.similarity('food', 'fuel'), lessThan(0.5));
    });
  });

  group('MessageSplitter', () {
    test('blank-line separated messages', () {
      expect(
        MessageSplitter.split(
          'Spent 20 USD at Costa\n\nCIB: you paid 89.00 EGP to Uber',
        ),
        hasLength(2),
      );
    });

    test('one message per line', () {
      expect(
        MessageSplitter.split(
          'Purchase of EGP 100.00 at Seoudi\nPurchase of EGP 55.50 at Uber',
        ),
        hasLength(2),
      );
    });

    test('a wrapped message stays whole', () {
      expect(
        MessageSplitter.split('Dear customer,\nEGP 100.00 was debited at Seoudi'),
        ['Dear customer, EGP 100.00 was debited at Seoudi'],
      );
    });
  });
}
