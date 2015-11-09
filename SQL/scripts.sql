INSERT INTO UserTest (id, username) VALUES (0, 'Kevin'); 
INSERT INTO UserTest (id, username) VALUES (1, 'Luis'); 
INSERT INTO UserTest (id, username) VALUES (2, 'Diogo'); 
INSERT INTO UserTest (id, username) VALUES (3, 'Joao');

INSERT INTO Administrator (user_id) VALUES (0);
INSERT INTO Registered (user_id, status_id) VALUES (0, 0);
INSERT INTO Registered (user_id, status_id) VALUES (1, 0);
INSERT INTO Registered (user_id, status_id) VALUES (2, 0);
INSERT INTO Registered (user_id, status_id) VALUES (3, 0);
INSERT INTO Administrator (user_id) VALUES (1);

INSERT INTO Auction (id, highest_bid) VALUES (0, 10);
INSERT INTO Auction (id, highest_bid) VALUES (1, 50);
INSERT INTO Auction (id, highest_bid) VALUES (2, 100);

INSERT INTO AuctionImage(id, auction_id, is_main) VALUES (0, 0, true);
INSERT INTO AuctionImage(id, auction_id, is_main) VALUES (1, 0, true);
INSERT INTO AuctionImage(id, auction_id, is_main) VALUES (2, 1, true);
INSERT INTO AuctionImage(id, auction_id, is_main) VALUES (3, 1, false);

INSERT INTO Bid (id, auction_id, registered, bid_value, valid) VALUES (0, 0, 0, 11, true);
INSERT INTO Bid (id, auction_id, registered, bid_value, valid) VALUES (1, 0, 0, 60, true);
INSERT INTO Bid (id, auction_id, registered, bid_value, valid) VALUES (2, 1, 0, 30, true);
INSERT INTO Bid (id, auction_id, registered, bid_value, valid) VALUES (3, 2, 0, 110, true);

INSERT INTO AuctionComment(id, content, visible) VALUES (0, 'Comentario obsceno', true);
INSERT INTO AuctionComment(id, content, visible) VALUES (1, 'I dont like your mother..', true);
INSERT INTO AuctionComment(id, content, visible) VALUES (2, 'the good comment', true);

INSERT INTO RemoveComment(id, auction_comment) VALUES(0, 1);

INSERT INTO Feedback(id, target_user_id, source_user_id) VALUES (0, 0, 0);
INSERT INTO Feedback(id, target_user_id, source_user_id) VALUES (1, 0, 1);

UPDATE Registered SET status_id = 1 WHERE id = 0;