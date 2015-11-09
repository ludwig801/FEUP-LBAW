CREATE INDEX auction_category_id ON Auction (category_id);

CREATE INDEX auction_image_auction_id ON AuctionImage (auction_id);

CREATE INDEX bid_auction_id ON Bid(auction_id);

CREATE INDEX feedback_target_user_id ON Feedback(target_user_id);

CREATE INDEX fav_auction_user_id ON FavoriteAuction(user_id);

CREATE INDEX fav_user_id ON FavoriteUser(source_user_id);

CREATE INDEX comm_auction_id ON Comment(auction_id);

CREATE INDEX msg_receiver_id ON Message(receiver_id);