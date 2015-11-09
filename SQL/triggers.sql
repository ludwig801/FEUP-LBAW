/* Test tables */
CREATE TABLE UserTest(
	id INTEGER NOT NULL PRIMARY KEY,
	username TEXT);
	
CREATE TABLE Administrator(
	user_id INTEGER NOT NULL REFERENCES UserTest(id));

CREATE TABLE Registered(
	user_id INTEGER NOT NULL REFERENCES UserTest(id),
	status_id INTEGER);
	
CREATE TABLE Auction(
	id INTEGER NOT NULL PRIMARY KEY,
	highest_bid INTEGER);
	
CREATE TABLE AuctionImage(
	id INTEGER NOT NULL PRIMARY KEY,
	auction_id INTEGER REFERENCES Auction(id),
	is_main BOOLEAN);
	
CREATE TABLE Bid(
	id INTEGER NOT NULL PRIMARY KEY,
	auction_id INTEGER REFERENCES Auction(id),
	registered INTEGER REFERENCES UserTest(id),
	bid_value INTEGER,
	valid BOOLEAN);
	
CREATE TABLE AuctionComment(
	id INTEGER NOT NULL PRIMARY KEY,
	content TEXT,
	visible BOOLEAN);
	
CREATE TABLE AdminAction(id INTEGER NOT NULL PRIMARY KEY);

CREATE TABLE BlockAuction(admin_action_id INTEGER REFERENCES AdminAction(id));
CREATE TABLE BlockUser(admin_action_id INTEGER REFERENCES AdminAction(id));
CREATE TABLE RemoveComment(
	admin_action_id INTEGER NOT NULL REFERENCES AdminAction(id),
	auction_comment INTEGER REFERENCES AuctionComment(id));

CREATE TABLE Feedback(
	id INTEGER NOT NULL PRIMARY KEY,
	target_user_id INTEGER REFERENCES UserTest(id),
	source_user_id INTEGER REFERENCES UserTest(id));

/*
	================================================
	BLOCK USER
	================================================
*/	
/* Procedure */
/* Assuming that 1 is the ID of the status BLOCKED */
CREATE FUNCTION check_bids() RETURNS TRIGGER AS $cancel_blocked_users_bids$
	BEGIN
		IF NEW.status_id = 1 THEN
			UPDATE Bid SET valid = false WHERE registered = NEW.id;
		END IF;
		RETURN NEW;
	END;
$cancel_blocked_users_bids$ LANGUAGE plpgsql;

/* Trigger */
CREATE TRIGGER cancel_blocked_users_bids
	AFTER UPDATE OF status_id ON Registered
	FOR EACH ROW
	EXECUTE PROCEDURE check_bids();

	
/* ================================================ */

/*
	================================================
	REMOVE COMMENT
	================================================
*/

CREATE FUNCTION remove_comment() RETURNS TRIGGER AS $set_comment_invisible$
	BEGIN
		UPDATE AuctionComment SET visible = false WHERE id = NEW.auction_comment;
		RETURN NEW;
	END;
$set_comment_invisible$ LANGUAGE plpgsql;


CREATE TRIGGER set_comment_invisible
	AFTER INSERT ON RemoveComment
	FOR EACH ROW
	EXECUTE PROCEDURE remove_comment();
	
/* ================================================ */

 /*
	================================================
	GIVE FEEDBACK
	================================================
*/       

CREATE FUNCTION check_feedback() RETURNS TRIGGER AS $feedback_given$
	BEGIN
		IF NEW.target_user_id = NEW.source_user_id THEN
		RAISE EXCEPTION 'Cannot give feedback to itself';
	END IF;
	RETURN NEW;
	END;
$feedback_given$ LANGUAGE plpgsql;

CREATE TRIGGER feedback_given 
	BEFORE INSERT ON Feedback
	FOR EACH ROW 
	EXECUTE PROCEDURE check_feedback();
	
	
 /*
	================================================
	MAKE A BID
	================================================
*/ 

CREATE FUNCTION check_bid() RETURNS TRIGGER AS $make_a_bid$
	BEGIN
		IF NEW.bid_value <= (SELECT highest_bid FROM Auction WHERE id = NEW.auction_id) THEN
			RAISE EXCEPTION 'Make a higher bid';
		END IF;
		RETURN NEW;
	END;
$make_a_bid$ LANGUAGE plpgsql;

CREATE TRIGGER make_a_bid
	BEFORE INSERT ON BID
	FOR EACH ROW
	EXECUTE PROCEDURE check_bid();
	
	
 /*
	================================================
	VERIFY MAIN IMAGE
	================================================
*/ 

CREATE FUNCTION check_auction_image() RETURNS TRIGGER AS $add_image_to_auction$
	BEGIN
		IF NEW.is_main THEN
			IF (SELECT COUNT(*) FROM AuctionImage WHERE is_main AND auction_id = NEW.auction_id) > 0 THEN
				RAISE EXCEPTION 'A main image already exists.';
			END IF;
		END IF;
		RETURN NEW;
	END;
$add_image_to_auction$ LANGUAGE plpgsql;

CREATE TRIGGER add_image_to_auction
	BEFORE INSERT ON AuctionImage
	FOR EACH ROW
	EXECUTE PROCEDURE check_auction_image();
	
	
 /*
	================================================
	REGISTER NEW USER
	================================================
*/ 
CREATE FUNCTION check_user_user_id() RETURNS TRIGGER AS $add_new_user$
	BEGIN
		IF (SELECT COUNT(*) FROM Administrator WHERE NEW.user_id = user_id) > 0 THEN
			RAISE EXCEPTION 'An user with the choosen user_id already exists.';
		END IF;
		RETURN NEW;
	END;
$add_new_user$ LANGUAGE plpgsql;

CREATE TRIGGER add_new_user
	BEFORE INSERT ON Registered
	FOR EACH ROW
	EXECUTE PROCEDURE check_user_user_id();
	
/*
	================================================
	REGISTER NEW ADMIN
	================================================
*/ 
CREATE FUNCTION check_admin_user_id() RETURNS TRIGGER AS $add_new_admin$
	BEGIN
		IF (SELECT COUNT(*) FROM Registered WHERE NEW.user_id = user_id) > 0 THEN
			RAISE EXCEPTION 'An user with the choosen user_id already exists.';
		END IF;
		RETURN NEW;
	END;
$add_new_admin$ LANGUAGE plpgsql;

CREATE TRIGGER add_new_admin
	BEFORE INSERT ON Administrator
	FOR EACH ROW
	EXECUTE PROCEDURE check_admin_user_id();
	
/*
	================================================
	BLOCK USER
	================================================
*/ 
CREATE FUNCTION check_block_user_id() RETURNS TRIGGER AS $block_user$
	BEGIN
		IF (SELECT COUNT(*) FROM BlockAuction WHERE NEW.admin_action_id = admin_action_id) > 0 THEN
			RAISE EXCEPTION 'An admin action with the choosen admin_action_id already exists.';
		IF (SELECT COUNT(*) FROM RemoveComment WHERE NEW.admin_action_id = admin_action_id) > 0 THEN
			RAISE EXCEPTION 'An admin action with the choosen admin_action_id already exists.';
		END IF;
		RETURN NEW;
	END;
$block_user$ LANGUAGE plpgsql;

CREATE TRIGGER block_user
	BEFORE INSERT ON BlockUser
	FOR EACH ROW
	EXECUTE PROCEDURE check_block_user_id();
	
/*
	================================================
	BLOCK AUCTION
	================================================
*/ 
CREATE FUNCTION check_block_auction_id() RETURNS TRIGGER AS $block_auction$
	BEGIN
		IF (SELECT COUNT(*) FROM BlockUser WHERE NEW.admin_action_id = admin_action_id) > 0 THEN
			RAISE EXCEPTION 'An admin action with the choosen admin_action_id already exists.';
		IF (SELECT COUNT(*) FROM RemoveComment WHERE NEW.admin_action_id = admin_action_id) > 0 THEN
			RAISE EXCEPTION 'An admin action with the choosen admin_action_id already exists.';
		END IF;
		RETURN NEW;
	END;
$block_user$ LANGUAGE plpgsql;

CREATE TRIGGER block_auction
	BEFORE INSERT ON BlockAuction
	FOR EACH ROW
	EXECUTE PROCEDURE check_block_auction_id();
	
/*
	================================================
	REMOVE COMMENT
	================================================
*/ 
CREATE FUNCTION check_remove_comment_id() RETURNS TRIGGER AS $remove_comment$
	BEGIN
		IF (SELECT COUNT(*) FROM BlockAuction WHERE NEW.admin_action_id = admin_action_id) > 0 THEN
			RAISE EXCEPTION 'An admin action with the choosen admin_action_id already exists.';
		IF (SELECT COUNT(*) FROM BlockUser WHERE NEW.admin_action_id = admin_action_id) > 0 THEN
			RAISE EXCEPTION 'An admin action with the choosen admin_action_id already exists.';
		END IF;
		RETURN NEW;
	END;
$remove_comment$ LANGUAGE plpgsql;

CREATE TRIGGER remove_comment
	BEFORE INSERT ON RemoveComment
	FOR EACH ROW
	EXECUTE PROCEDURE check_remove_comment_id();
	
/*
	================================================
	REPORT USER
	================================================
*/ 
CREATE FUNCTION check_report_user_id() RETURNS TRIGGER AS $report_user$
	BEGIN
		IF (SELECT COUNT(*) FROM ReportedAuction WHERE NEW.report_id = report_id) > 0 THEN
			RAISE EXCEPTION 'A report with the choosen report_id already exists.';
		END IF;
		RETURN NEW;
	END;
$report_user$ LANGUAGE plpgsql;

CREATE TRIGGER report_user
	BEFORE INSERT ON ReportedUser
	FOR EACH ROW
	EXECUTE PROCEDURE check_report_user_id();
	
/*
	================================================
	REPORT AUCTION
	================================================
*/ 
CREATE FUNCTION check_report_auction_id() RETURNS TRIGGER AS $report_auction$
	BEGIN
		IF (SELECT COUNT(*) FROM ReportedUser WHERE NEW.report_id = report_id) > 0 THEN
			RAISE EXCEPTION 'A report with the choosen report_id already exists.';
		END IF;
		RETURN NEW;
	END;
$report_auction$ LANGUAGE plpgsql;

CREATE TRIGGER report_auction
	BEFORE INSERT ON ReportedAuction
	FOR EACH ROW
	EXECUTE PROCEDURE check_report_auction_id();
	
	
