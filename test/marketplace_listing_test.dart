import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crystal_grimoire_fresh/screens/marketplace_screen.dart';

void main() {
  test('MarketplaceListing.fromMap captures moderation metadata', () {
    final submittedAt = Timestamp.fromDate(DateTime.utc(2025, 3, 20, 18));
    final data = {
      'title': 'Amethyst cluster',
      'description': 'High grade cluster from Uruguay',
      'priceCents': 4200,
      'sellerId': 'seller-123',
      'sellerName': 'Mystic Merchant',
      'status': 'pending_review',
      'category': 'Clusters',
      'crystalId': 'amethyst-cluster',
      'moderation': {
        'status': 'pending',
        'submittedAt': submittedAt,
        'notes': '',
      },
    };

    final listing = MarketplaceListing.fromMap('listing-1', data);

    expect(listing.id, 'listing-1');
    expect(listing.isPending, isTrue);
    expect(listing.submittedAt, submittedAt.toDate());
    expect(listing.reviewNotes, isNull);
  });

  test('MarketplaceListing.reviewNotes prefers rejectionReason when present', () {
    final data = {
      'title': 'Rose Quartz',
      'description': 'Pocket stone',
      'priceCents': 900,
      'sellerId': 'seller-321',
      'sellerName': 'Crystal Keeper',
      'status': 'rejected',
      'rejectionReason': 'Photos are too dark to verify clarity',
      'moderation': {
        'status': 'rejected',
        'notes': 'duplicate entry',
      },
    };

    final listing = MarketplaceListing.fromMap('listing-2', data);

    expect(listing.isRejected, isTrue);
    expect(listing.reviewNotes, 'Photos are too dark to verify clarity');
  });
}
