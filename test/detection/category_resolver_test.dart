import 'package:flourish/core/detection/category_resolver.dart';
import 'package:flourish/core/detection/local_parser.dart';
import 'package:flourish/core/detection/transaction_candidate.dart';
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

final defaults = [
  cat(1, 'Salary', 'income'),
  cat(2, 'Food & Drinks'),
  cat(3, 'Transport'),
  cat(4, 'Shopping'),
  cat(5, 'Bills & Utilities'),
  cat(9, 'Other'),
];

TransactionCandidate parse(String text) => LocalTransactionParser.parse(text);

void main() {
  test('keyword concept maps to an existing category', () {
    final r = CategoryResolver(categories: defaults).resolve(
      parse('Paid 89.00 EGP to Uber'),
    );
    expect(r.categoryId, 3);
    expect(r.reason, CategoryReason.concept);
  });

  test('groceries fall back to Food & Drinks instead of a new category', () {
    final r = CategoryResolver(categories: defaults).resolve(
      parse('Spent EGP 640 at Carrefour'),
    );
    expect(r.categoryId, 2);
  });

  test('a user rule beats everything', () {
    final r = CategoryResolver(
      categories: defaults,
      rules: const [
        CategoryRule(
          id: 'r',
          pattern: 'uber',
          matchType: 'merchant',
          categoryId: 5,
          type: 'expense',
        ),
      ],
      memory: [
        MerchantMemory(
          merchantKey: 'uber',
          type: 'expense',
          categoryId: 4,
          hits: 5,
          lastUsed: DateTime(2026),
        ),
      ],
    ).resolve(parse('Paid 89.00 EGP to Uber'));
    expect(r.categoryId, 5);
    expect(r.reason, CategoryReason.rule);
  });

  test('merchant memory beats keyword concepts', () {
    final r = CategoryResolver(
      categories: defaults,
      memory: [
        MerchantMemory(
          merchantKey: 'uber',
          type: 'expense',
          categoryId: 5,
          hits: 2,
          lastUsed: DateTime(2026),
        ),
      ],
    ).resolve(parse('Paid 89.00 EGP to Uber'));
    expect(r.categoryId, 5);
    expect(r.reason, CategoryReason.memory);
  });

  test('past notes vote when there is no memory', () {
    final r = CategoryResolver(
      categories: defaults,
      history: const [('Zed Pharmacy • Imported', 'expense', 5)],
    ).resolve(parse('Spent 120 EGP at Zed Pharmacy'));
    expect(r.categoryId, 5);
    expect(r.reason, CategoryReason.history);
  });

  test('an AI proposal is deduplicated against similar names', () {
    final c = parse('Spent 50 USD at Xyz').copyWith(
      aiProposedCategory: const ProposedCategory(
        name: 'shoppings',
        type: 'expense',
        icon: 'shopping_bag',
        colorIndex: 2,
      ),
    );
    final r = CategoryResolver(categories: defaults).resolve(c);
    expect(r.categoryId, 4);
  });

  test('an AI proposal becomes a sanitized new category', () {
    final c = parse('Spent 50 USD at Petsmart').copyWith(
      aiProposedCategory: const ProposedCategory(
        name: '  pet supplies ',
        type: 'expense',
        icon: 'not-an-icon',
        colorIndex: 40,
        parentName: 'Shopping',
      ),
    );
    final r = CategoryResolver(categories: defaults).resolve(c);
    expect(r.isNew, isTrue);
    expect(r.proposed!.name, 'Pet Supplies');
    expect(r.proposed!.icon, 'category');
    expect(r.proposed!.colorIndex, 11);
  });

  test('new categories can be switched off', () {
    final c = parse('Spent 50 USD at Petsmart').copyWith(
      aiProposedCategory: const ProposedCategory(
        name: 'Pets',
        type: 'expense',
        icon: 'pets',
        colorIndex: 1,
      ),
    );
    final r = CategoryResolver(
      categories: defaults,
      allowNewCategories: false,
    ).resolve(c);
    expect(r.categoryId, 9);
    expect(r.reason, CategoryReason.fallback);
  });

  test('a batch reuses proposals and caps new categories', () {
    TransactionCandidate withProposal(String name) =>
        parse('Spent 5 USD at Shop').copyWith(
          aiProposedCategory: ProposedCategory(
            name: name,
            type: 'expense',
            icon: 'category',
            colorIndex: 0,
            parentName: 'Shopping',
          ),
        );
    final results = CategoryResolver(categories: defaults).resolveAll([
      withProposal('Pets'),
      withProposal('pets'),
      withProposal('Hobbies'),
      withProposal('Garden'),
    ], maxNew: 2);
    expect(results[0].proposed!.name, 'Pets');
    expect(results[1].proposed!.name, 'Pets');
    expect(results[2].proposed!.name, 'Hobbies');
    expect(results[3].categoryId, 4, reason: 'over the cap → parent');
  });

  test('unknown merchants fall back to Other, never the first category', () {
    final r = CategoryResolver(categories: defaults).resolve(
      parse('Spent 5 USD at Qwerty'),
    );
    expect(r.categoryId, 9);
  });

  test('similarity', () {
    expect(CategoryResolver.similarity('food', 'food'), 1);
    expect(CategoryResolver.similarity('groceries', 'grocerie'), greaterThan(0.85));
    expect(CategoryResolver.similarity('food', 'fuel'), lessThan(0.5));
  });
}
