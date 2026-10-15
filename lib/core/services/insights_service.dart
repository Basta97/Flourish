import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flourish/core/models/insight.dart';
import 'package:flourish/core/theme/app_colors.dart';
import 'package:flourish/data/database/database.dart';

class InsightsService {
  static double calculateHealthScore({
    required List<Transaction> transactions,
    required List<Account> accounts,
    required List<Budget> budgets,
  }) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);

    final monthlyTx = transactions
        .where(
          (t) =>
              !t.transactionDate.isBefore(monthStart) &&
              !t.transactionDate.isAfter(monthEnd),
        )
        .toList();

    final income = monthlyTx
        .where((t) => t.type == 'income')
        .fold<double>(0, (s, t) => s + t.amount);
    final expense = monthlyTx
        .where((t) => t.type == 'expense')
        .fold<double>(0, (s, t) => s + t.amount);

    double savingsRateScore = 0;
    if (income > 0) {
      final savingsRate = (income - expense) / income;
      savingsRateScore = (savingsRate * 100).clamp(0, 30);
    }

    double budgetScore = 0;
    if (budgets.isNotEmpty) {
      int onTrack = 0;
      for (final b in budgets) {
        final spent = monthlyTx
            .where((t) => t.categoryId == b.categoryId && t.type == 'expense')
            .fold<double>(0, (s, t) => s + t.amount);
        if (spent <= b.amount) onTrack++;
      }
      budgetScore = (onTrack / budgets.length) * 25;
    } else {
      budgetScore = 12.5;
    }

    double trendScore = 12.5;
    final prevMonthStart = DateTime(now.year, now.month - 1, 1);
    final prevMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59, 999);
    final prevExpense = transactions
        .where(
          (t) =>
              !t.transactionDate.isBefore(prevMonthStart) &&
              !t.transactionDate.isAfter(prevMonthEnd) &&
              t.type == 'expense',
        )
        .fold<double>(0, (s, t) => s + t.amount);
    if (prevExpense > 0 && expense < prevExpense) {
      trendScore = 25;
    } else if (prevExpense > 0 && expense > prevExpense) {
      trendScore = max(0, 25 - ((expense - prevExpense) / prevExpense * 25));
    }

    double diversificationScore = 0;
    if (accounts.length >= 2) {
      diversificationScore = 20;
    } else if (accounts.isNotEmpty) {
      diversificationScore = 10;
    }

    return (savingsRateScore + budgetScore + trendScore + diversificationScore)
        .clamp(0, 100);
  }

  static List<Insight> detectAnomalies({
    required List<Transaction> transactions,
    required List<Category> categories,
  }) {
    final catMap = {for (var c in categories) c.id: c};
    final expenses = transactions.where((t) => t.type == 'expense').toList();
    if (expenses.isEmpty) return [];

    final categoryAmounts = <int, List<double>>{};
    for (final t in expenses) {
      categoryAmounts.putIfAbsent(t.categoryId, () => []).add(t.amount);
    }

    final anomalies = <Insight>[];
    for (final entry in categoryAmounts.entries) {
      if (entry.value.length < 3) continue;
      final amounts = entry.value;
      final mean = amounts.reduce((a, b) => a + b) / amounts.length;
      final variance =
          amounts.map((a) => pow(a - mean, 2)).reduce((a, b) => a + b) /
          amounts.length;
      final stdDev = sqrt(variance);
      if (stdDev == 0) continue;

      final recent = expenses.where((t) => t.categoryId == entry.key).toList()
        ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
      if (recent.isEmpty) continue;
      final latest = recent.first;
      final zScore = (latest.amount - mean) / stdDev;

      if (zScore.abs() > 2) {
        final cat = catMap[entry.key];
        final isHigh = zScore > 0;
        anomalies.add(
          Insight(
            id: 'anomaly_${entry.key}_${latest.id}',
            type: InsightType.anomaly,
            title: isHigh
                ? 'Unusual ${cat?.name ?? 'spending'}'
                : 'Lower ${cat?.name ?? 'spending'} than usual',
            message: isHigh
                ? 'Your ${cat?.name ?? ''} spending of \$${latest.amount.toStringAsFixed(0)} is ${(zScore).toStringAsFixed(1)}x higher than your average (\$${mean.toStringAsFixed(0)})'
                : 'Your recent ${cat?.name ?? ''} spending was notably lower than average',
            icon: isHigh ? Icons.trending_up : Icons.trending_down,
            color: isHigh ? AppColors.expense : AppColors.income,
            metricValue: zScore,
            metricLabel: 'z-score',
          ),
        );
      }
    }

    return anomalies;
  }

  static Map<int, double> suggestBudgets({
    required List<Transaction> transactions,
    required List<Category> categories,
  }) {
    final expenseCats = categories.where((c) => c.type == 'expense').toList();
    final now = DateTime.now();
    final suggestions = <int, double>{};

    for (final cat in expenseCats) {
      final monthlyTotals = <double>[];
      for (int i = 0; i < 3; i++) {
        final m = DateTime(now.year, now.month - i, 1);
        final mEnd = DateTime(m.year, m.month + 1, 0, 23, 59, 59, 999);
        final total = transactions
            .where(
              (t) =>
                  t.categoryId == cat.id &&
                  t.type == 'expense' &&
                  !t.transactionDate.isBefore(m) &&
                  !t.transactionDate.isAfter(mEnd),
            )
            .fold<double>(0, (s, t) => s + t.amount);
        if (total > 0) monthlyTotals.add(total);
      }
      if (monthlyTotals.isNotEmpty) {
        suggestions[cat.id] =
            monthlyTotals.reduce((a, b) => a + b) / monthlyTotals.length;
      }
    }

    return suggestions;
  }

  static List<double> forecastCashFlow({
    required List<Transaction> transactions,
    int daysAhead = 30,
  }) {
    final now = DateTime.now();
    final points = <double>[];

    final last30 = transactions
        .where(
          (t) =>
              t.transactionDate.isAfter(now.subtract(const Duration(days: 30))),
        )
        .toList();

    final dailyNets = <int, double>{};
    for (final t in last30) {
      final dayKey = t.transactionDate.millisecondsSinceEpoch ~/ (86400000);
      final amount = t.type == 'income' ? t.amount : -t.amount;
      dailyNets[dayKey] = (dailyNets[dayKey] ?? 0) + amount;
    }

    if (dailyNets.isEmpty) {
      return List.filled(daysAhead, 0);
    }

    final avgDailyNet =
        dailyNets.values.reduce((a, b) => a + b) / dailyNets.length;
    double cumulative = 0;
    for (int i = 0; i < daysAhead; i++) {
      cumulative += avgDailyNet;
      points.add(cumulative);
    }

    return points;
  }

  static List<Insight> analyzeHabits({
    required List<Transaction> transactions,
    required List<Category> categories,
  }) {
    final habits = <Insight>[];
    final now = DateTime.now();

    final weekendTx = transactions.where((t) {
      if (t.type != 'expense') return false;
      final wd = t.transactionDate.weekday;
      return wd == DateTime.saturday || wd == DateTime.sunday;
    }).toList();

    final weekdayTx = transactions.where((t) {
      if (t.type != 'expense') return false;
      final wd = t.transactionDate.weekday;
      return wd != DateTime.saturday && wd != DateTime.sunday;
    }).toList();

    if (weekendTx.isNotEmpty && weekdayTx.isNotEmpty) {
      final avgWeekend =
          weekendTx.fold<double>(0, (s, t) => s + t.amount) /
          (weekendTx.length / 2).ceil();
      final avgWeekday =
          weekdayTx.fold<double>(0, (s, t) => s + t.amount) /
          (weekdayTx.length / 5).ceil();
      if (avgWeekend > avgWeekday * 1.3 && avgWeekday > 0) {
        final pct = ((avgWeekend - avgWeekday) / avgWeekday * 100)
            .toStringAsFixed(0);
        habits.add(
          Insight(
            id: 'habit_weekend',
            type: InsightType.habit,
            title: 'Weekend spender',
            message:
                'You spend about $pct% more per day on weekends than weekdays',
            icon: Icons.weekend,
            color: AppColors.warning,
          ),
        );
      }
    }

    final thisMonth = transactions.where((t) {
      if (t.type != 'expense') return false;
      return t.transactionDate.month == now.month &&
          t.transactionDate.year == now.year;
    }).toList();

    final lastMonth = transactions.where((t) {
      if (t.type != 'expense') return false;
      final lm = DateTime(now.year, now.month - 1);
      return t.transactionDate.month == lm.month &&
          t.transactionDate.year == lm.year;
    }).toList();

    if (thisMonth.isNotEmpty && lastMonth.isNotEmpty) {
      final thisTotal = thisMonth.fold<double>(0, (s, t) => s + t.amount);
      final lastTotal = lastMonth.fold<double>(0, (s, t) => s + t.amount);
      if (lastTotal > 0) {
        final change = ((thisTotal - lastTotal) / lastTotal * 100);
        if (change.abs() > 15) {
          habits.add(
            Insight(
              id: 'habit_monthly_trend',
              type: change > 0 ? InsightType.warning : InsightType.achievement,
              title: change > 0 ? 'Spending is up' : 'Great savings month',
              message: change > 0
                  ? 'Your spending increased by ${change.toStringAsFixed(0)}% compared to last month'
                  : 'You spent ${change.abs().toStringAsFixed(0)}% less than last month. Keep it up!',
              icon: change > 0 ? Icons.trending_up : Icons.emoji_events,
              color: change > 0 ? AppColors.expense : AppColors.income,
              metricValue: change,
            ),
          );
        }
      }
    }

    return habits;
  }

  static int? suggestCategoryFromNote(
    String note,
    List<Transaction> pastTransactions, {
    List<Category> categories = const <Category>[],
    String? type,
  }) {
    if (note.trim().isEmpty) return null;
    final lower = note.toLowerCase();
    final categoryScores = <int, int>{};
    final eligibleCategories = categories
        .where((category) => type == null || category.type == type)
        .toList();

    for (final t in pastTransactions) {
      if (type != null && t.type != type) continue;
      final tNote = t.note?.trim().toLowerCase();
      if (tNote != null && tNote.isNotEmpty) {
        if (lower.contains(tNote) || tNote.contains(lower)) {
          categoryScores[t.categoryId] =
              (categoryScores[t.categoryId] ?? 0) + 3;
        }
      }
    }

    final keywords = <String, String>{
      'coffee': 'restaurant',
      'starbucks': 'restaurant',
      'lunch': 'restaurant',
      'dinner': 'restaurant',
      'food': 'restaurant',
      'grocery': 'restaurant',
      'uber': 'directions_car',
      'gas': 'directions_car',
      'fuel': 'directions_car',
      'taxi': 'directions_car',
      'salary': 'payments',
      'paycheck': 'payments',
      'wage': 'payments',
      'netflix': 'movie',
      'spotify': 'movie',
      'gym': 'favorite',
      'doctor': 'favorite',
      'pharmacy': 'favorite',
      'rent': 'home',
      'electricity': 'receipt_long',
      'water bill': 'receipt_long',
      'internet': 'receipt_long',
      'amazon': 'shopping_bag',
      'clothes': 'shopping_bag',
      'book': 'school',
    };

    for (final entry in keywords.entries) {
      if (lower.contains(entry.key)) {
        for (final category in eligibleCategories) {
          final name = category.name.toLowerCase();
          if (category.icon == entry.value || name.contains(entry.key)) {
            categoryScores[category.id] =
                (categoryScores[category.id] ?? 0) + 6;
          }
        }
      }
    }

    if (categoryScores.isEmpty) return null;
    final sorted = categoryScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  static List<Insight> getAllInsights({
    required List<Transaction> transactions,
    required List<Account> accounts,
    required List<Category> categories,
    required List<Budget> budgets,
  }) {
    final insights = <Insight>[];

    final score = calculateHealthScore(
      transactions: transactions,
      accounts: accounts,
      budgets: budgets,
    );
    insights.add(
      Insight(
        id: 'health_score',
        type: InsightType.suggestion,
        title: 'Financial Health Score',
        message: score >= 70
            ? 'Your finances are in great shape!'
            : score >= 40
            ? 'There\'s room for improvement in your spending habits'
            : 'Consider setting budgets and reducing unnecessary expenses',
        icon: Icons.favorite,
        color: AppColors.healthScoreColor(score),
        metricValue: score,
        metricLabel: '/100',
      ),
    );

    insights.addAll(
      detectAnomalies(transactions: transactions, categories: categories),
    );
    insights.addAll(
      analyzeHabits(transactions: transactions, categories: categories),
    );

    return insights;
  }
}
