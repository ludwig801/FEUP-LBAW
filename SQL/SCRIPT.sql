DROP TABLE IF EXISTS Person;

CREATE TABLE Person (
  id SERIAL PRIMARY KEY,
  username varchar(20) UNIQUE NOT NULL,
  password varchar(50) NOT NULL,
  email varchar(50) UNIQUE NOT NULL,
  creation_date timestamp NOT NULL
);

DROP TABLE IF EXISTS Image;

CREATE TABLE Image (
  id SERIAL PRIMARY KEY,
  path varchar(100) NOT NULL
);

DROP TABLE IF EXISTS UserStatus;

CREATE TABLE UserStatus (
  id SERIAL PRIMARY KEY,
  status varchar(20) NOT NULL
);

DROP TABLE IF EXISTS Registered;

CREATE TABLE Registered (
  user_id integer REFERENCES Person(id) PRIMARY KEY,
  name varchar(50) NOT NULL,
  address varchar(150) NOT NULL,
  contact varchar(50) NOT NULL,
  avatar_id integer REFERENCES Image(id),
  status_id integer REFERENCES UserStatus(id)
);

DROP TABLE IF EXISTS AuctionStatus;

CREATE TABLE AuctionStatus (
  id SERIAL PRIMARY KEY,
  status varchar(20) NOT NULL
);

DROP TABLE IF EXISTS Category;

CREATE TABLE Category (
  id SERIAL PRIMARY KEY,
  image_id integer REFERENCES Image(id),
  name varchar(20) NOT NULL,
  description varchar(50) NOT NULL
);

DROP TABLE IF EXISTS Auction;

CREATE TABLE Auction (
  id SERIAL PRIMARY KEY,
  owner_id integer REFERENCES Registered(user_id),
  category_id integer REFERENCES Category(id),
  title varchar(50) NOT NULL,
  summary varchar(100) NOT NULL,
  description varchar(500) NOT NULL,
  starting_bid numeric(10,2) NOT NULL CHECK (starting_bid >= 0),
  starting_time timestamp NOT NULL,
  ending_time timestamp NULL CHECK (starting_time < ending_time),
  status_id integer REFERENCES AuctionStatus(id),
  winner_id integer REFERENCES Registered(user_id) NULL,
  highest_bid numeric(10,2) NOT NULL
);

DROP TABLE IF EXISTS Bid;

CREATE TABLE Bid (
  id SERIAL PRIMARY KEY,
  user_id integer REFERENCES Registered(user_id),
  auction_id integer REFERENCES Auction(id),
  value numeric(10,2) CHECK (value > 0),
  creation_date timestamp NOT NULL,
  valid boolean default TRUE NOT NULL
);

DROP TABLE IF EXISTS FavoriteUser;

CREATE TABLE FavoriteUser (
  target_user_id integer REFERENCES Registered(user_id),
  source_user_id integer REFERENCES Registered(user_id),
  PRIMARY KEY(target_user_id, source_user_id)
);

DROP TABLE IF EXISTS FavoriteAuction;

CREATE TABLE FavoriteAuction (
  user_id integer REFERENCES Registered(user_id),
  auction_id integer REFERENCES Auction(id),
  PRIMARY KEY(user_id, auction_id)
);

DROP TABLE IF EXISTS AuctionImage;

CREATE TABLE AuctionImage (
  image_id integer REFERENCES Image(id) PRIMARY KEY,
  auction_id integer REFERENCES Auction(id),
  is_main boolean default FALSE NOT NULL
);

DROP TABLE IF EXISTS Comment;

CREATE TABLE Comment (
  id SERIAL PRIMARY KEY,
  user_id integer REFERENCES Registered(user_id),
  auction_id integer REFERENCES Auction(id),
  content varchar(150) NOT NULL,
  creation_date timestamp NOT NULL,
  visible boolean default TRUE NOT NULL
);

DROP TABLE IF EXISTS Report;

CREATE TABLE Report (
  id SERIAL PRIMARY KEY,
  owner_id integer REFERENCES Registered(user_id),
  creation_date timestamp NOT NULL,
  motive varchar(50) default 'TOA Violation' NOT NULL
);

DROP TABLE IF EXISTS ReportedAuction;

CREATE TABLE ReportedAuction (
  report_id integer REFERENCES Report(id),
  auction_id integer REFERENCES Auction(id),
  PRIMARY KEY(report_id, auction_id)
);

DROP TABLE IF EXISTS ReportedUser;

CREATE TABLE ReportedUser (
  report_id integer REFERENCES Report(id),
  user_id integer REFERENCES Registered(user_id),
  PRIMARY KEY(report_id, user_id)
);

DROP TABLE IF EXISTS Message;

CREATE TABLE Message (
  id SERIAL PRIMARY KEY,
  sender_id integer REFERENCES Person(id),
  receiver_id integer REFERENCES Person(id) CHECK(receiver_id != sender_id),
  topic varchar(50) default 'No Topic' NOT NULL,
  content varchar(50) NOT NULL,
  creation_date timestamp NOT NULL,
  read boolean default FALSE NOT NULL
);

DROP TABLE IF EXISTS Administrator;

CREATE TABLE Administrator (
  user_id integer REFERENCES Person(id) PRIMARY KEY
);

DROP TABLE IF EXISTS Feedback;

CREATE TABLE Feedback (
  id SERIAL PRIMARY KEY,
  source_user_id integer REFERENCES Registered(user_id),
  target_user_id integer REFERENCES Registered(user_id) CHECK(source_user_id != target_user_id),
  evaluation integer NOT NULL CHECK (evaluation > 0 AND evaluation < 11),
  comment varchar(150) default 'No Comment' NOT NULL
);

DROP TABLE IF EXISTS AdminAction;

CREATE TABLE AdminAction (
  id SERIAL PRIMARY KEY,
  admin_id integer REFERENCES Administrator(user_id),
  motive varchar(50) default 'TOA Violation' NOT NULL,
  creation_date timestamp NOT NULL
);

DROP TABLE IF EXISTS BlockUser;

CREATE TABLE BlockUser (
  admin_action_id integer REFERENCES AdminAction(id),
  user_id integer REFERENCES Registered(user_id),
  PRIMARY KEY(admin_action_id, user_id)
);

DROP TABLE IF EXISTS RemoveComment;

CREATE TABLE RemoveComment (
  admin_action_id integer REFERENCES AdminAction(id),
  comment_id integer REFERENCES Comment(id),
  PRIMARY KEY(admin_action_id, comment_id)
);

DROP TABLE IF EXISTS BlockAuction;

CREATE TABLE BlockAuction (
  admin_action_id integer REFERENCES AdminAction(id),
  auction_id integer REFERENCES Auction(id),
  PRIMARY KEY(admin_action_id, auction_id)
);

CREATE INDEX auction_category_id ON Auction (category_id);

CREATE INDEX auction_image_auction_id ON AuctionImage (auction_id);

CREATE INDEX bid_auction_id ON Bid(auction_id);

CREATE INDEX feedback_target_user_id ON Feedback(target_user_id);

CREATE INDEX fav_auction_user_id ON FavoriteAuction(user_id);

CREATE INDEX fav_user_id ON FavoriteUser(source_user_id);

CREATE INDEX comm_auction_id ON Comment(auction_id);

CREATE INDEX msg_receiver_id ON Message(receiver_id);

CREATE FUNCTION check_bids() RETURNS TRIGGER AS $cancel_blocked_users_bids$
BEGIN
	IF NEW.status_id = 2 THEN
		UPDATE Bid SET valid = false WHERE registered = NEW.user_id;
                UPDATE Auction SET status = 3 WHERE owner_id = NEW.user_id;
	END IF;
	RETURN NEW;
END;
$cancel_blocked_users_bids$ LANGUAGE plpgsql;

CREATE TRIGGER cancel_blocked_users_bids
       AFTER UPDATE OF status_id ON Registered
       FOR EACH ROW
       EXECUTE PROCEDURE check_bids();

CREATE FUNCTION remove_comment() RETURNS TRIGGER AS $set_comment_invisible$
BEGIN
	UPDATE Comment SET visible = false WHERE id = NEW.comment_id;
	RETURN NEW;
END;
$set_comment_invisible$ LANGUAGE plpgsql;

CREATE TRIGGER set_comment_invisible
       AFTER INSERT ON RemoveComment
       FOR EACH ROW
       EXECUTE PROCEDURE remove_comment();

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

CREATE FUNCTION check_block_user_id() RETURNS TRIGGER AS $block_user$
	BEGIN
		IF (SELECT COUNT(*) FROM BlockAuction WHERE NEW.admin_action_id = admin_action_id) > 0 THEN
			RAISE EXCEPTION 'An admin action with the choosen admin_action_id already exists.';
		END IF;
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

CREATE FUNCTION check_remove_comment_id() RETURNS TRIGGER AS $remove_comment$
	BEGIN
		IF (SELECT COUNT(*) FROM BlockAuction WHERE NEW.admin_action_id = admin_action_id) > 0 THEN
			RAISE EXCEPTION 'An admin action with the choosen admin_action_id already exists.';
		END IF;
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

CREATE FUNCTION check_block_auction_id() RETURNS TRIGGER AS $block_auction$
	BEGIN
		IF (SELECT COUNT(*) FROM BlockUser WHERE NEW.admin_action_id = admin_action_id) > 0 THEN
			RAISE EXCEPTION 'An admin action with the choosen admin_action_id already exists.';
		END IF;
		IF (SELECT COUNT(*) FROM RemoveComment WHERE NEW.admin_action_id = admin_action_id) > 0 THEN
			RAISE EXCEPTION 'An admin action with the choosen admin_action_id already exists.';
		END IF;
		RETURN NEW;
	END;
$block_auction$ LANGUAGE plpgsql;

CREATE TRIGGER block_auction
	BEFORE INSERT ON BlockAuction
	FOR EACH ROW
	EXECUTE PROCEDURE check_block_auction_id();

CREATE FUNCTION check_bid() RETURNS TRIGGER AS $make_a_bid$
	BEGIN
		IF NEW.value <= (SELECT highest_bid FROM Auction WHERE id = NEW.auction_id) THEN
			RAISE EXCEPTION 'Make a higher bid';
		END IF;
		RETURN NEW;
	END;
$make_a_bid$ LANGUAGE plpgsql;

CREATE TRIGGER make_a_bid
	BEFORE INSERT ON BID
	FOR EACH ROW
	EXECUTE PROCEDURE check_bid();

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

INSERT INTO Person (username,password,email,creation_date) VALUES ('Veda','ZGC91DBB6YL','sit.amet@nullavulputatedui.net','2016-01-11 08:28:25'),('Abdul','MZV07RQD7UV','eu@nonsapienmolestie.ca','2015-05-30 14:05:26'),('Cadman','KDA99SLT3DM','risus.a.ultricies@risus.co.uk','2016-02-11 03:34:00'),('Orson1','BPS06ZYL9EJ','at@turpisnonenim.net','2014-10-10 22:04:22'),('Hakeem','KBA17GYR9SV','Pellentesque.habitant@arcueu.com','2014-10-17 20:01:10'),('Bertha','DKT41HID2YV','at.augue@lacusAliquamrutrum.edu','2015-01-12 19:40:39'),('Ivana','EHY36RYT0NP','congue@ornare.com','2015-07-30 22:48:01'),('Omar','OTA98MMA4NP','ac.mattis@ametnullaDonec.org','2014-09-13 19:08:41'),('Hilda','RGK71ZYS7IU','ut.mi@egetodio.com','2016-01-31 16:21:47'),('Jeremy','CKU16QDS9BZ','mauris@necleo.com','2014-12-24 16:43:24');
INSERT INTO Person (username,password,email,creation_date) VALUES ('Brent','QRR06JUG5PC','nec.luctus@euplacerateget.org','2014-07-01 12:47:41'),('Peter','FVP38YML3XR','senectus.et@nec.co.uk','2014-06-02 20:44:28'),('Nita','GGI25OYA6BQ','est.mollis.non@aaliquet.edu','2015-03-12 09:16:11'),('Genevieve','LSW01JGI1BR','in.dolor.Fusce@mitemporlorem.net','2015-05-25 17:35:48'),('Madaline','UYA03GQL7DN','Aliquam@Nulla.co.uk','2014-12-30 10:29:39'),('Elvis','MRD69OPU6SN','odio.a@vestibulum.com','2014-07-06 18:54:07'),('Jade','DOU13WLA9UV','Aenean.massa@mi.com','2016-03-08 20:59:47'),('Rhiannon','QCV07VNX9TI','a.dui@adipiscing.net','2015-03-02 00:21:45'),('Buckminster','GCP89TCD9IO','dictum.Phasellus.in@acturpisegestas.com','2015-01-31 11:54:36'),('Dylan','KCU10PQQ6BE','lectus@neceuismod.co.uk','2015-03-15 01:34:22');
INSERT INTO Person (username,password,email,creation_date) VALUES ('Hilary','CBK28QJT2VS','scelerisque.mollis@auctorvitae.co.uk','2015-09-11 21:03:02'),('Justin','RXS77OIQ8DP','Aliquam.gravida.mauris@Vivamusnibh.ca','2015-03-18 16:12:03'),('Ulla','STO49OAA6MP','Nulla.interdum@Mauriseuturpis.net','2014-05-09 05:52:13'),('Idola','OHV00XDJ4JD','venenatis@risusIn.net','2015-12-12 11:20:34'),('Igor','EEG88VRY7CM','parturient.montes.nascetur@Sed.org','2016-03-30 20:59:12'),('Lisandra','EKS18TOZ4BJ','nec@dolorquam.edu','2016-02-24 09:36:43'),('Griffin','YSV86RJY8PV','Phasellus@Nuncullamcorper.org','2015-11-07 00:28:33'),('Dante','JBN86UHL3TL','ut.erat@duiinsodales.co.uk','2015-08-30 11:42:04'),('Zelda','LGN33BMO2AI','interdum.libero@nibh.org','2015-04-17 18:26:39'),('Tanya','NVU00KEJ2OX','tincidunt.dui.augue@mifringilla.net','2015-10-02 05:38:23');
INSERT INTO Person (username,password,email,creation_date) VALUES ('Yardley','KDG38QLQ3CB','vitae.orci@mollis.net','2014-06-30 19:58:56'),('Linda','SYT52RST0XQ','nec.tempus.mauris@Suspendissesed.net','2014-05-25 08:15:27'),('Ahmed','NAV52NVT3YM','erat.Etiam@nibhPhasellusnulla.co.uk','2014-08-30 20:51:08'),('Ryder','VFS70AVM2OM','tellus@Donecporttitortellus.org','2015-12-07 10:22:51'),('Harriet','FDW16ORK5ZN','lacus.Aliquam@ametrisusDonec.ca','2015-10-11 05:13:15'),('Cameran','EYT87LNA4YL','tempor.arcu@mi.ca','2015-09-03 11:11:09'),('Jerry','HXC03FCD4PX','risus.at.fringilla@ipsumprimisin.co.uk','2014-06-07 20:21:46'),('Cleo','AON95LHF6XW','senectus@Nam.com','2015-10-27 14:30:53'),('Orson','MLJ80YUW8AH','euismod@idrisus.com','2014-04-30 00:03:31'),('Adena','NVV28CQO3EM','molestie.arcu.Sed@elitCurabitur.com','2014-06-11 01:00:19');
INSERT INTO Person (username,password,email,creation_date) VALUES ('Veronica1','VUL96VHI1SO','ornare.sagittis.felis@acurnaUt.com','2015-05-26 18:40:40'),('Rinah','SSH83YUN9OF','ultrices.posuere.cubilia@vitae.net','2015-08-07 03:55:41'),('Philip','RPN64FRM2FG','eu@scelerisquemollis.edu','2014-08-16 12:22:20'),('Dean','COV90XUQ0RN','Aliquam@egestashendrerit.net','2016-03-12 10:47:19'),('Xandra','HVO50TAQ8LD','vitae.erat.Vivamus@tellusimperdietnon.com','2015-05-21 10:31:52'),('Abel','KGD23EBE2CO','hendrerit.consectetuer.cursus@sapienAenean.ca','2016-03-27 12:46:36'),('Ashely','RON08WHH3JM','egestas.nunc.sed@aenim.org','2014-10-29 11:17:25'),('Whilemina','YUA33HMD6GG','Phasellus@tinciduntnunc.co.uk','2015-03-24 14:37:59'),('Phillip','TCK03KJF7FR','Sed.malesuada@semper.org','2014-07-28 12:24:36'),('Chadwick','GVA67SZI0CT','Nullam.vitae.diam@erosProin.ca','2014-11-06 21:09:20');

INSERT INTO Image (path) VALUES ('est mauris, rhoncus id,'),('consequat enim diam vel'),('et, euismod et, commodo at, libero. Morbi accumsan'),('pellentesque, tellus sem mollis dui, in sodales'),('non, lobortis quis, pede. Suspendisse'),('dui quis accumsan convallis, ante lectus convallis est,'),('orci lacus vestibulum lorem, sit amet ultricies sem'),('ac metus vitae'),('molestie arcu. Sed eu nibh vulputate mauris sagittis'),('Ut sagittis lobortis mauris. Suspendisse aliquet molestie');
INSERT INTO Image (path) VALUES ('malesuada fames ac turpis'),('Cras pellentesque. Sed dictum. Proin eget odio. Aliquam vulputate'),('iaculis quis, pede.'),('scelerisque dui. Suspendisse ac metus'),('Etiam imperdiet dictum magna. Ut tincidunt orci quis lectus. Nullam'),('metus. Aliquam erat volutpat. Nulla facilisis. Suspendisse commodo tincidunt nibh.'),('justo eu arcu. Morbi sit amet massa. Quisque'),('orci. Ut sagittis lobortis mauris. Suspendisse aliquet molestie'),('eleifend non, dapibus'),('augue porttitor interdum.');
INSERT INTO Image (path) VALUES ('ut, pellentesque'),('risus a ultricies adipiscing, enim'),('nonummy. Fusce fermentum fermentum'),('Praesent'),('pharetra'),('Curae; Donec tincidunt. Donec vitae erat vel pede'),('velit. Quisque varius. Nam porttitor scelerisque neque. Nullam nisl.'),('ut dolor dapibus gravida. Aliquam tincidunt, nunc'),('purus. Nullam scelerisque neque sed sem'),('risus varius orci, in consequat enim diam vel');
INSERT INTO Image (path) VALUES ('laoreet'),('rutrum eu,'),('ut dolor dapibus'),('nunc nulla'),('consectetuer adipiscing'),('est. Mauris eu turpis. Nulla aliquet. Proin velit. Sed malesuada'),('dapibus quam quis diam. Pellentesque habitant morbi tristique senectus'),('sagittis lobortis mauris. Suspendisse'),('erat volutpat. Nulla dignissim. Maecenas ornare egestas ligula. Nullam'),('velit eu sem. Pellentesque ut ipsum ac mi');
INSERT INTO Image (path) VALUES ('lacus. Cras interdum. Nunc sollicitudin'),('eget nisi dictum augue malesuada malesuada. Integer id magna et'),('nec urna suscipit nonummy. Fusce fermentum'),('Vestibulum ut eros non enim commodo hendrerit. Donec porttitor'),('ligula tortor, dictum eu,'),('dapibus quam'),('convallis est, vitae sodales nisi magna sed dui. Fusce aliquam,'),('feugiat'),('arcu eu odio'),('diam lorem, auctor quis, tristique ac, eleifend vitae, erat. Vivamus');
INSERT INTO Image (path) VALUES ('imperdiet dictum magna. Ut tincidunt orci'),('est, vitae'),('tellus justo sit amet nulla. Donec non justo. Proin'),('pellentesque eget, dictum'),('enim nisl elementum purus, accumsan interdum'),('ipsum leo'),('enim, gravida sit amet, dapibus id, blandit'),('non dui nec'),('rhoncus. Nullam velit dui, semper et, lacinia vitae, sodales at,'),('ante bibendum ullamcorper. Duis cursus, diam at pretium');
INSERT INTO Image (path) VALUES ('cursus vestibulum. Mauris'),('Cras convallis convallis dolor. Quisque tincidunt pede'),('sit amet, consectetuer adipiscing elit. Aliquam auctor, velit eget'),('Vivamus euismod urna. Nullam lobortis'),('arcu.'),('imperdiet ullamcorper. Duis at lacus. Quisque purus sapien, gravida'),('netus et malesuada fames ac turpis egestas. Fusce aliquet'),('ut'),('augue. Sed molestie. Sed'),('purus.');
INSERT INTO Image (path) VALUES ('eu, placerat eget, venenatis a, magna. Lorem'),('ante.'),('nunc sit amet metus. Aliquam erat volutpat. Nulla facilisis.'),('mollis non, cursus non, egestas a, dui. Cras pellentesque.'),('urna et arcu imperdiet'),('libero at'),('Nunc ac sem ut dolor dapibus'),('nec mauris blandit mattis. Cras'),('hendrerit'),('Curabitur egestas nunc sed libero. Proin sed turpis nec');
INSERT INTO Image (path) VALUES ('mus. Proin vel arcu eu odio tristique pharetra.'),('eleifend egestas. Sed pharetra, felis eget'),('Vivamus'),('Integer sem elit,'),('purus. Nullam scelerisque neque sed sem egestas'),('Sed eu nibh vulputate'),('enim mi tempor lorem, eget mollis lectus pede et risus.'),('tincidunt, neque vitae semper egestas, urna justo faucibus'),('parturient montes,'),('posuere');
INSERT INTO Image (path) VALUES ('sed'),('Vestibulum ut eros non enim commodo hendrerit. Donec'),('est ac facilisis facilisis, magna tellus faucibus'),('sodales elit erat vitae risus.'),('eros nec tellus. Nunc lectus pede, ultrices a, auctor non,'),('a, scelerisque sed, sapien. Nunc'),('amet nulla. Donec non justo. Proin non massa'),('ac, fermentum vel, mauris. Integer sem elit,'),('Cras pellentesque. Sed dictum. Proin eget odio. Aliquam vulputate'),('Cras eu tellus eu augue porttitor interdum. Sed auctor odio');

INSERT INTO UserStatus (status) VALUES ('Active'), ('Blocked');

INSERT INTO Registered (user_id,name,address,contact,avatar_id,status_id) VALUES (6,'Daquan V. Sears','P.O. Box 703, 5703 Erat Av.','810-2682',1,2),(7,'Paul K. Aguirre','P.O. Box 599, 599 Non Street','231-1436',2,1),(8,'Calista V. Myers','Ap #454-1981 Lorem, St.','1-243-628-1527',3,2),(9,'Harding F. Snyder','761-1998 Quis Rd.','1-339-717-6341',4,1),(10,'Yen Q. Pittman','Ap #919-1128 Sed Street','866-0079',5,1),(11,'Edward J. Moore','P.O. Box 646, 4510 Donec St.','652-9397',6,2),(12,'Martin X. Allison','9307 Diam. St.','1-113-910-8570',7,1),(13,'Dieter X. Turner','426-8747 Risus. Av.','1-632-893-5610',8,2),(14,'Patricia B. Church','P.O. Box 440, 6853 Mauris, Ave','941-0984',9,1),(15,'Alexis Z. Bean','471-1544 Quis, Ave','285-3133',10,2);
INSERT INTO Registered (user_id,name,address,contact,avatar_id,status_id) VALUES (16,'Aquila J. Livingston','Ap #227-5128 At Street','1-632-422-1571',11,1),(17,'Hilel O. Valencia','7549 Feugiat St.','512-0270',12,2),(18,'Simone S. Hopkins','P.O. Box 460, 5188 Metus St.','482-0223',13,1),(19,'Fleur L. Huff','Ap #545-4199 Convallis Road','302-1950',14,2),(20,'Joel F. Chan','718-1077 Ultrices, Rd.','817-0833',15,1),(21,'Tanner S. Miranda','7990 Iaculis St.','1-402-619-2117',16,1),(22,'Ramona G. Conner','649-7945 Nec, Avenue','820-1697',17,1),(23,'Ainsley O. Spence','Ap #217-7413 Montes, Ave','1-248-780-0957',18,2),(24,'Giselle B. Mendoza','P.O. Box 886, 6310 Mauris Rd.','1-469-430-3623',19,2),(25,'Thane Y. Lawrence','555-9013 A, Rd.','1-887-831-6329',20,1);
INSERT INTO Registered (user_id,name,address,contact,avatar_id,status_id) VALUES (26,'Halla X. Moore','Ap #823-2350 Aliquet St.','476-7823',21,2),(27,'Omar N. Sellers','388-1979 Porta St.','1-413-449-8636',22,1),(28,'Alexander Q. Boone','Ap #978-975 Pellentesque St.','1-566-250-7998',23,2),(29,'Otto G. Lamb','7692 Amet Avenue','1-472-812-1335',24,2),(30,'Beck K. Petty','2906 Gravida Avenue','1-707-666-3724',25,1),(31,'Amelia G. Wise','774-8413 Semper Av.','1-912-923-3725',26,1),(32,'Madonna F. Robbins','1277 Fringilla, Rd.','413-6978',27,1),(33,'Ursa V. Kinney','Ap #408-8610 At, Rd.','1-513-381-3171',28,1),(34,'Emi L. Lancaster','P.O. Box 936, 4248 Vestibulum Ave','262-4308',29,1),(35,'Sylvester Y. Salas','Ap #745-8465 Justo Av.','1-944-587-4816',30,2);
INSERT INTO Registered (user_id,name,address,contact,avatar_id,status_id) VALUES (36,'Tatum D. Franks','165-864 Volutpat. Rd.','458-5126',31,2),(37,'Amanda F. Fuentes','5627 Cursus Street','878-6661',32,2),(38,'Graiden R. Walters','P.O. Box 966, 9838 Volutpat. Rd.','1-283-914-7660',33,2),(39,'Daria Q. Ryan','884-6478 Accumsan Av.','189-8652',34,2),(40,'Lareina B. Hickman','877-7636 Ultrices Rd.','1-402-609-0609',35,1),(41,'Kuame B. Sawyer','Ap #187-8467 Aliquam Rd.','1-233-752-5752',36,2),(42,'Athena V. Compton','339-7047 Risus, Av.','1-349-841-8643',37,1),(43,'Shoshana H. Gutierrez','2258 Arcu. Road','1-954-174-4097',38,1),(44,'Owen B. Phillips','946-1300 Purus. Av.','1-620-337-9468',39,1),(45,'Tasha V. Lane','Ap #777-5367 Tempor, St.','834-1994',40,2);
INSERT INTO Registered (user_id,name,address,contact,avatar_id,status_id) VALUES (46,'Xander V. Snow','768-8432 Nec St.','1-848-532-7029',41,1),(47,'Dane A. Green','453-7809 Vel, Ave','1-416-833-1012',42,2),(48,'Amir F. Hoffman','Ap #800-5926 Vitae St.','1-942-121-0850',43,1),(49,'Slade I. Knox','P.O. Box 226, 2587 Lectus St.','821-7727',44,1),(50,'Virginia D. Herrera','519-336 Ullamcorper. Avenue','408-2125',45,1);

INSERT INTO AuctionStatus (status) VALUES ('Active'), ('Inactive'), ('Blocked');

INSERT INTO FavoriteUser (target_user_id,source_user_id) VALUES (10,29),(26,11),(33,48),(22,39),(14,26),(9,26),(25,24),(48,20),(27,35),(50,18);
INSERT INTO FavoriteUser (target_user_id,source_user_id) VALUES (25,46),(28,46),(25,8),(20,39),(29,7),(41,22),(49,33),(14,37),(23,22),(48,43);
INSERT INTO FavoriteUser (target_user_id,source_user_id) VALUES (47,34),(8,47),(24,31),(20,13),(21,13),(37,43),(38,46),(35,41),(31,19),(10,33);
INSERT INTO FavoriteUser (target_user_id,source_user_id) VALUES (49,15),(44,12),(12,33),(9,6),(6,42),(42,20),(13,44),(19,33),(47,47),(45,19);
INSERT INTO FavoriteUser (target_user_id,source_user_id) VALUES (49,14),(19,46),(49,18),(43,19),(23,15),(27,26),(34,42),(11,45),(23,44),(50,23);

INSERT INTO Category (image_id, name, description) VALUES (1, 'Cars', 'Cars'),(2, 'Motorcylces', 'Motorcylces'), (3,'Trucks', 'Trucks'), (4,'Real Estate', 'Real Estate'),(5, 'Technology', 'Technology');
INSERT INTO Category (image_id, name, description) VALUES (6, 'Furniture', 'Furniture'),(7,'Fashion', 'Fashion'),(8,'Leisure', 'Leisure'),(9,'Sports', 'Sports'),(10,'Services', 'Services'),(11,'Pets', 'Pets'),(12,'Other', 'Other');

INSERT INTO Auction (owner_id,category_id,title,summary,description,starting_bid,starting_time,ending_time,status_id,winner_id,highest_bid) VALUES (16,12,'Lorem ipsum dolor sit','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor.',20,'2014-04-16 23:58:08','2015-04-26 18:17:30',2,23,40),(26,4,'Lorem ipsum dolor','Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','Lorem ipsum dolor sit amet, consectetuer adipiscing',20,'2014-04-12 02:52:29','2016-03-25 08:01:06',2,12,21),(30,6,'Lorem ipsum dolor','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer aliquam adipiscing lacus. Ut nec urna',11,'2014-04-16 19:27:51','2016-01-05 12:07:07',3,44,29),(15,1,'Lorem ipsum dolor sit amet,','Lorem ipsum dolor sit amet, consectetuer adipiscing','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed',14,'2014-04-15 22:34:53','2015-06-23 05:21:12',1,43,35),(27,2,'Lorem ipsum','Lorem ipsum','Lorem ipsum dolor sit amet,',12,'2014-04-14 00:11:45','2016-01-10 13:21:04',3,36,39),(35,5,'Lorem ipsum dolor','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','Lorem ipsum dolor sit amet,',19,'2014-04-15 00:59:59','2015-10-22 14:38:31',3,46,22),(11,8,'Lorem','Lorem ipsum dolor sit','Lorem ipsum',19,'2014-04-14 02:15:44','2015-04-21 09:58:49',1,17,28),(22,12,'Lorem ipsum dolor','Lorem ipsum dolor sit amet, consectetuer','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor.',13,'2014-04-14 03:08:35','2016-02-15 06:15:36',3,6,41),(46,3,'Lorem ipsum dolor sit amet,','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','Lorem ipsum dolor sit',11,'2014-04-16 01:28:41','2016-02-28 05:45:47',3,26,42),(42,3,'Lorem','Lorem','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer aliquam',18,'2014-04-12 01:39:54','2016-01-30 09:57:36',3,10,34);
INSERT INTO Auction (owner_id,category_id,title,summary,description,starting_bid,starting_time,ending_time,status_id,winner_id,highest_bid) VALUES (17,4,'Lorem ipsum dolor sit','Lorem ipsum dolor','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer aliquam adipiscing lacus. Ut',19,'2014-04-12 19:49:06','2016-02-18 15:04:36',2,46,34),(28,4,'Lorem ipsum dolor','Lorem ipsum dolor','Lorem',11,'2014-04-14 12:42:59','2015-11-25 10:42:36',2,48,40),(12,11,'Lorem ipsum','Lorem ipsum dolor','Lorem ipsum dolor sit',10,'2014-04-16 22:46:53','2015-04-22 15:28:34',1,33,48),(15,1,'Lorem ipsum dolor sit','Lorem ipsum dolor sit','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer aliquam adipiscing lacus.',17,'2014-04-15 08:59:18','2015-05-14 06:31:15',2,23,50),(17,6,'Lorem ipsum','Lorem','Lorem ipsum dolor sit amet,',17,'2014-04-12 05:13:56','2015-08-13 14:05:31',3,44,34),(39,12,'Lorem','Lorem ipsum dolor sit amet, consectetuer','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer aliquam adipiscing lacus. Ut nec urna et arcu',12,'2014-04-16 22:42:51','2015-10-07 10:13:22',3,20,43),(49,9,'Lorem ipsum dolor sit','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur',12,'2014-04-16 08:03:06','2015-10-22 06:38:45',3,47,26),(21,3,'Lorem','Lorem ipsum dolor','Lorem ipsum dolor sit',15,'2014-04-15 00:40:04','2016-04-10 23:04:24',1,24,46),(49,10,'Lorem ipsum dolor','Lorem ipsum dolor sit amet, consectetuer','Lorem',15,'2014-04-13 02:45:54','2015-09-04 04:22:46',2,50,32),(29,8,'Lorem ipsum','Lorem ipsum dolor sit amet, consectetuer','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer aliquam adipiscing lacus. Ut',12,'2014-04-14 15:15:25','2016-02-20 03:35:31',1,14,42);
INSERT INTO Auction (owner_id,category_id,title,summary,description,starting_bid,starting_time,ending_time,status_id,winner_id,highest_bid) VALUES (17,2,'Lorem ipsum dolor sit amet,','Lorem ipsum','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer aliquam adipiscing',11,'2014-04-16 01:25:55','2015-09-18 22:33:46',3,42,27),(32,12,'Lorem ipsum dolor','Lorem ipsum dolor sit amet,','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer aliquam adipiscing lacus. Ut nec urna',10,'2014-04-15 08:32:43','2015-10-21 14:45:58',3,50,44),(19,3,'Lorem ipsum dolor','Lorem ipsum dolor sit amet, consectetuer adipiscing','Lorem ipsum dolor sit',19,'2014-04-12 23:39:07','2015-09-24 23:20:12',2,14,20),(41,8,'Lorem ipsum','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','Lorem ipsum dolor sit',14,'2014-04-16 08:18:23','2015-05-30 20:38:51',3,17,41),(28,10,'Lorem ipsum','Lorem ipsum dolor sit amet, consectetuer adipiscing','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer aliquam adipiscing',13,'2014-04-15 03:39:29','2015-06-06 23:28:00',3,8,34),(29,9,'Lorem ipsum dolor','Lorem ipsum dolor sit','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer aliquam',20,'2014-04-15 07:53:56','2015-11-21 12:45:12',2,10,29),(32,8,'Lorem ipsum dolor sit','Lorem ipsum','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer aliquam adipiscing lacus.',10,'2014-04-14 19:31:28','2015-12-28 22:09:57',2,43,34),(44,4,'Lorem ipsum','Lorem ipsum dolor','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer aliquam adipiscing lacus. Ut',12,'2014-04-16 03:35:42','2016-02-12 02:01:04',2,41,21),(6,9,'Lorem ipsum dolor','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer',11,'2014-04-16 14:44:25','2015-05-13 03:51:19',3,16,21),(45,8,'Lorem','Lorem ipsum dolor sit amet, consectetuer','Lorem',19,'2014-04-14 23:49:50','2016-02-17 20:28:31',2,37,33);
INSERT INTO Auction (owner_id,category_id,title,summary,description,starting_bid,starting_time,ending_time,status_id,winner_id,highest_bid) VALUES (22,12,'Lorem ipsum dolor sit','Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer aliquam adipiscing lacus. Ut',15,'2014-04-16 13:10:04','2015-12-17 17:59:45',3,14,41),(15,4,'Lorem','Lorem ipsum dolor','Lorem ipsum dolor',15,'2014-04-16 23:45:22','2015-11-27 05:48:39',1,50,23),(48,2,'Lorem','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer',10,'2014-04-14 01:18:27','2016-02-19 23:03:55',2,24,29),(8,1,'Lorem ipsum dolor','Lorem ipsum dolor sit amet, consectetuer adipiscing','Lorem ipsum',10,'2014-04-16 19:14:00','2015-08-17 23:57:09',1,45,44),(15,3,'Lorem ipsum','Lorem ipsum dolor sit amet,','Lorem ipsum dolor',19,'2014-04-15 03:24:31','2015-05-20 21:08:46',2,34,40),(48,9,'Lorem ipsum dolor sit','Lorem','Lorem ipsum dolor sit',16,'2014-04-12 09:51:46','2015-12-09 21:15:28',3,8,44),(32,9,'Lorem ipsum dolor sit amet,','Lorem ipsum dolor sit amet,','Lorem ipsum dolor sit amet, consectetuer adipiscing elit.',18,'2014-04-12 12:45:04','2015-11-19 06:34:02',3,22,46),(43,6,'Lorem','Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer aliquam adipiscing lacus. Ut nec urna',10,'2014-04-14 14:10:48','2016-03-13 23:42:11',1,47,31),(32,6,'Lorem ipsum dolor','Lorem ipsum dolor sit amet,','Lorem ipsum',16,'2014-04-15 02:27:00','2015-06-20 05:58:39',1,17,32),(33,12,'Lorem ipsum','Lorem','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur',15,'2014-04-15 09:52:12','2015-06-23 21:28:30',3,46,47);
INSERT INTO Auction (owner_id,category_id,title,summary,description,starting_bid,starting_time,ending_time,status_id,winner_id,highest_bid) VALUES (49,2,'Lorem ipsum dolor sit amet,','Lorem ipsum dolor sit','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer aliquam adipiscing',13,'2014-04-14 12:20:13','2015-06-13 00:40:22',3,33,27),(17,4,'Lorem ipsum dolor sit amet,','Lorem ipsum dolor sit','Lorem ipsum',20,'2014-04-16 03:03:36','2016-03-29 19:06:08',1,32,31),(26,11,'Lorem','Lorem ipsum dolor sit amet,','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer',13,'2014-04-12 12:58:33','2016-01-20 14:00:39',3,35,20),(8,2,'Lorem','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer aliquam adipiscing lacus. Ut nec urna et',16,'2014-04-14 12:09:57','2015-04-23 11:33:14',1,48,35),(12,3,'Lorem ipsum dolor sit amet,','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','Lorem',13,'2014-04-12 00:06:23','2016-02-22 14:17:33',1,25,34),(15,4,'Lorem ipsum dolor','Lorem ipsum','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer aliquam adipiscing lacus. Ut nec urna',15,'2014-04-12 20:09:43','2015-08-27 10:33:21',3,27,27),(31,9,'Lorem ipsum dolor sit amet,','Lorem ipsum dolor','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer aliquam adipiscing lacus. Ut nec',10,'2014-04-12 20:14:02','2015-07-21 20:29:57',3,49,27),(41,11,'Lorem ipsum dolor sit','Lorem ipsum dolor sit amet, consectetuer','Lorem',15,'2014-04-16 01:05:46','2015-06-06 15:36:41',1,17,45),(17,5,'Lorem ipsum','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed tortor. Integer aliquam adipiscing',14,'2014-04-12 19:08:29','2015-12-22 09:18:27',2,38,31),(48,6,'Lorem ipsum dolor sit','Lorem ipsum','Lorem ipsum dolor sit amet,',20,'2014-04-12 08:01:09','2015-07-29 19:07:21',1,8,41);

INSERT INTO Bid (user_id,auction_id,value,creation_date,valid) VALUES (23,45,118,'2016-04-15 22:28:40','true'),(22,4,137,'2016-04-15 23:58:16','true'),(35,14,116,'2016-04-18 17:16:43','true'),(7,37,142,'2016-04-12 14:30:55','true'),(33,11,137,'2016-04-16 12:09:39','true'),(35,41,105,'2016-04-14 13:03:27','true'),(22,15,105,'2016-04-18 12:51:32','true'),(11,43,115,'2016-04-11 11:43:27','true'),(11,42,101,'2016-04-18 07:33:30','true'),(39,30,126,'2016-04-21 06:18:57','true');
INSERT INTO Bid (user_id,auction_id,value,creation_date,valid) VALUES (44,7,143,'2016-04-15 10:53:02','true'),(42,4,147,'2016-04-21 21:17:02','true'),(33,20,124,'2016-04-10 07:29:46','true'),(41,50,107,'2016-04-14 09:36:50','true'),(6,7,150,'2016-04-16 06:41:46','true'),(38,32,113,'2016-04-19 21:21:20','true'),(14,28,108,'2016-04-21 00:01:16','true'),(24,34,115,'2016-04-17 15:04:33','true'),(40,1,126,'2016-04-15 07:01:16','true'),(14,3,124,'2016-04-12 13:28:14','true');
INSERT INTO Bid (user_id,auction_id,value,creation_date,valid) VALUES (27,23,149,'2016-04-19 13:37:46','true'),(9,15,133,'2016-04-14 03:44:31','true'),(26,50,130,'2016-04-19 18:45:33','true'),(29,17,143,'2016-04-12 21:23:36','true'),(48,18,124,'2016-04-15 08:11:15','true'),(48,26,150,'2016-04-18 16:30:34','true'),(36,37,107,'2016-04-20 17:24:14','true'),(32,23,129,'2016-04-20 19:05:29','true'),(39,49,143,'2016-04-12 22:59:21','true'),(38,38,147,'2016-04-18 22:14:21','true');
INSERT INTO Bid (user_id,auction_id,value,creation_date,valid) VALUES (41,24,120,'2016-04-11 12:30:17','true'),(32,5,120,'2016-04-20 11:53:58','true'),(47,32,101,'2016-04-14 18:20:24','true'),(7,26,142,'2016-04-11 07:30:31','true'),(41,6,134,'2016-04-15 13:24:07','true'),(10,12,149,'2016-04-18 06:04:38','true'),(15,8,136,'2016-04-12 16:25:50','true'),(35,8,141,'2016-04-20 19:13:39','true'),(43,14,127,'2016-04-17 10:40:59','true'),(46,36,112,'2016-04-17 08:05:29','true');
INSERT INTO Bid (user_id,auction_id,value,creation_date,valid) VALUES (34,34,140,'2016-04-18 05:03:58','true'),(7,28,112,'2016-04-11 14:19:24','true'),(17,1,110,'2016-04-13 08:27:28','true'),(48,49,105,'2016-04-12 09:01:26','true'),(46,36,141,'2016-04-18 12:50:25','true'),(6,5,119,'2016-04-19 07:14:38','true'),(35,13,141,'2016-04-16 22:42:41','true'),(44,1,113,'2016-04-18 03:47:31','true'),(6,17,141,'2016-04-21 02:28:12','true'),(32,23,131,'2016-04-15 03:23:25','true');

INSERT INTO FavoriteUser (target_user_id,source_user_id) VALUES (32,34),(13,32),(28,45),(22,29),(50,32),(48,25),(39,48),(42,6),(17,21),(46,26);
INSERT INTO FavoriteUser (target_user_id,source_user_id) VALUES (48,45),(30,37),(37,35),(12,26),(19,35),(46,33),(41,8),(6,34),(46,13),(9,38);
INSERT INTO FavoriteUser (target_user_id,source_user_id) VALUES (46,50),(23,33),(22,48),(12,36),(25,31),(24,7),(47,17),(9,32),(41,48),(29,47);
INSERT INTO FavoriteUser (target_user_id,source_user_id) VALUES (41,6),(45,7),(30,31),(18,49),(21,12),(17,29),(35,22),(18,42),(23,11),(37,27);
INSERT INTO FavoriteUser (target_user_id,source_user_id) VALUES (30,45),(8,41),(18,43),(23,29),(41,16),(47,41),(20,17),(30,32),(50,26),(31,27);

INSERT INTO FavoriteAuction (user_id,auction_id) VALUES (37,9),(21,4),(32,46),(38,46),(42,39),(32,39),(49,25),(45,27),(29,16),(42,31);
INSERT INTO FavoriteAuction (user_id,auction_id) VALUES (25,50),(10,31),(19,37),(38,23),(6,13),(44,39),(42,22),(33,48),(11,27),(16,48);
INSERT INTO FavoriteAuction (user_id,auction_id) VALUES (12,33),(13,45),(19,49),(17,23),(23,42),(19,30),(28,17),(22,15),(12,35),(44,24);
INSERT INTO FavoriteAuction (user_id,auction_id) VALUES (31,45),(32,5),(10,46),(9,34),(20,15),(34,13),(36,25),(16,46),(8,27),(6,17);
INSERT INTO FavoriteAuction (user_id,auction_id) VALUES (43,6),(28,34),(20,29),(13,17),(24,1),(29,21),(39,37),(32,34),(40,3),(46,47);

INSERT INTO AuctionImage (image_id,auction_id,is_main) VALUES (46,1,'1'),(47,2,'1'),(48,3,'1'),(49,4,'1'),(50,5,'1'),(51,6,'1'),(52,7,'1'),(53,8,'1'),(54,9,'1'),(55,10,'1');
INSERT INTO AuctionImage (image_id,auction_id,is_main) VALUES (56,11,'1'),(57,12,'1'),(58,13,'1'),(59,14,'1'),(60,15,'1'),(61,16,'1'),(62,17,'1'),(63,18,'1'),(64,19,'1'),(65,20,'1');
INSERT INTO AuctionImage (image_id,auction_id,is_main) VALUES (66,21,'1'),(67,22,'1'),(68,23,'1'),(69,24,'1'),(70,25,'1'),(71,26,'1'),(72,27,'1'),(73,28,'1'),(74,29,'1'),(75,30,'1');
INSERT INTO AuctionImage (image_id,auction_id,is_main) VALUES (76,31,'1'),(77,32,'1'),(78,33,'1'),(79,34,'1'),(80,35,'1'),(81,36,'1'),(82,37,'1'),(83,38,'1'),(84,39,'1'),(85,40,'1');
INSERT INTO AuctionImage (image_id,auction_id,is_main) VALUES (86,41,'1'),(87,42,'1'),(88,43,'1'),(89,44,'1'),(90,45,'1'),(91,46,'1'),(92,47,'1'),(93,48,'1'),(94,49,'1'),(95,50,'1');

INSERT INTO Comment (user_id,auction_id,content,creation_date,visible) VALUES (46,8,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','2014-07-31 14:32:19','true'),(30,24,'Lorem ipsum','2016-03-08 09:07:07','true'),(36,34,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','2015-02-20 11:36:28','true'),(28,23,'Lorem ipsum dolor','2015-08-21 00:04:33','true'),(23,18,'Lorem ipsum dolor sit amet,','2014-10-28 01:29:44','true'),(44,40,'Lorem ipsum dolor sit','2014-05-20 06:18:42','true'),(43,17,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','2014-12-04 21:49:21','true'),(46,12,'Lorem ipsum dolor sit amet,','2015-06-03 03:21:51','true'),(26,11,'Lorem ipsum dolor sit amet, consectetuer','2015-07-11 07:18:38','true'),(23,23,'Lorem ipsum dolor','2014-06-21 04:42:12','true');
INSERT INTO Comment (user_id,auction_id,content,creation_date,visible) VALUES (46,40,'Lorem ipsum','2015-06-23 09:31:46','true'),(26,49,'Lorem ipsum dolor sit','2015-12-05 11:58:22','true'),(33,12,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','2015-08-31 07:52:10','true'),(46,28,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','2014-08-31 06:59:11','true'),(42,26,'Lorem ipsum dolor sit amet, consectetuer adipiscing','2014-09-27 09:23:34','true'),(23,37,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','2015-06-06 17:22:21','true'),(39,24,'Lorem ipsum dolor sit amet,','2015-04-07 13:53:58','true'),(49,12,'Lorem ipsum dolor','2014-08-07 03:32:13','true'),(28,35,'Lorem ipsum dolor sit amet, consectetuer','2014-12-20 13:55:16','true'),(47,39,'Lorem ipsum dolor sit','2015-10-03 03:07:45','true');
INSERT INTO Comment (user_id,auction_id,content,creation_date,visible) VALUES (28,30,'Lorem','2015-07-21 19:27:26','true'),(27,30,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','2014-08-27 00:23:52','true'),(25,25,'Lorem ipsum dolor','2014-07-17 04:32:26','true'),(24,8,'Lorem ipsum','2015-11-29 16:48:28','true'),(21,21,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','2014-09-13 08:27:06','true'),(44,28,'Lorem ipsum dolor sit amet,','2015-05-29 16:37:11','true'),(20,33,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','2015-06-27 22:06:55','true'),(44,47,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','2015-07-22 05:51:02','true'),(36,23,'Lorem','2016-03-21 13:02:34','true'),(26,6,'Lorem ipsum dolor','2016-04-11 13:07:40','true');
INSERT INTO Comment (user_id,auction_id,content,creation_date,visible) VALUES (41,25,'Lorem ipsum dolor sit amet, consectetuer','2015-11-04 19:25:55','true'),(41,7,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','2015-10-16 21:42:54','true'),(45,2,'Lorem ipsum dolor','2016-01-03 03:02:54','true'),(44,18,'Lorem ipsum dolor','2015-08-25 10:07:10','true'),(44,7,'Lorem ipsum','2015-11-18 16:49:22','true'),(43,12,'Lorem ipsum dolor sit','2015-11-21 11:06:31','true'),(33,24,'Lorem ipsum','2015-12-16 12:07:24','true'),(31,32,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur','2014-04-12 08:54:43','true'),(48,50,'Lorem','2015-02-08 20:28:50','true'),(41,34,'Lorem ipsum dolor sit amet, consectetuer','2015-07-07 07:13:36','true');
INSERT INTO Comment (user_id,auction_id,content,creation_date,visible) VALUES (25,27,'Lorem','2016-01-11 06:28:26','true'),(42,34,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','2015-01-21 05:21:36','true'),(42,16,'Lorem ipsum dolor','2015-07-10 18:42:40','true'),(20,35,'Lorem','2015-01-03 03:04:10','true'),(43,3,'Lorem','2014-05-13 06:03:16','true'),(20,43,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Curabitur sed','2016-04-09 21:59:56','true'),(30,45,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','2015-02-09 17:49:43','true'),(39,43,'Lorem ipsum dolor','2014-10-12 06:15:14','true'),(47,11,'Lorem ipsum dolor sit amet, consectetuer adipiscing elit.','2014-09-30 01:00:50','true'),(24,46,'Lorem ipsum dolor sit amet,','2014-08-28 09:16:56','true');

INSERT INTO Report (owner_id,creation_date,motive) VALUES (38,'2015-09-18 23:02:38','Lorem ipsum dolor'),(33,'2015-06-15 12:13:01','Lorem'),(40,'2015-04-19 03:48:35','Lorem ipsum dolor sit'),(37,'2015-08-10 00:52:49','Lorem ipsum dolor'),(27,'2016-01-20 04:27:05','Lorem'),(47,'2015-06-27 01:12:16','Lorem ipsum dolor sit amet,'),(40,'2015-03-01 13:55:20','Lorem ipsum'),(48,'2015-04-07 09:57:37','Lorem ipsum'),(20,'2015-08-17 06:22:30','Lorem'),(45,'2014-11-29 07:53:42','Lorem ipsum dolor sit');

INSERT INTO ReportedAuction (report_id,auction_id) VALUES (6,18),(7,10),(8,49),(9,13),(10,45);

INSERT INTO ReportedUser (report_id,user_id) VALUES (1,11),(2,23),(3,47),(4,12),(5,47);

INSERT INTO Message (sender_id,receiver_id,topic,content,creation_date,read) VALUES (32,26,'Lorem ipsum dolor','Lorem ipsum dolor sit','2014-10-24 22:08:54','false '),(17,19,'Lorem','Lorem','2015-12-09 08:15:07','false '),(28,21,'Lorem ipsum dolor','Lorem','2016-03-10 00:42:54','false '),(42,12,'Lorem','Lorem','2015-12-24 15:29:46','false '),(22,38,'Lorem ipsum','Lorem ipsum dolor sit amet,','2015-05-09 23:28:55','false '),(32,21,'Lorem ipsum dolor','Lorem ipsum dolor','2015-02-20 01:28:06','false '),(42,6,'Lorem ipsum dolor','Lorem ipsum','2015-05-04 19:16:09','false '),(25,38,'Lorem','Lorem ipsum dolor sit','2016-01-18 20:41:12','false '),(9,41,'Lorem ipsum','Lorem ipsum dolor sit','2014-07-24 05:01:54','false '),(32,43,'Lorem ipsum','Lorem ipsum dolor','2015-08-01 05:29:28','false ');
INSERT INTO Message (sender_id,receiver_id,topic,content,creation_date,read) VALUES (45,44,'Lorem ipsum dolor','Lorem ipsum dolor sit','2015-07-13 12:27:06',' true'),(12,28,'Lorem ipsum','Lorem ipsum dolor sit amet,','2015-11-25 08:27:02',' true'),(7,25,'Lorem ipsum dolor','Lorem ipsum dolor sit amet,','2015-11-10 21:12:41',' true'),(36,46,'Lorem ipsum dolor','Lorem ipsum dolor sit','2015-04-22 18:17:48',' true'),(45,50,'Lorem ipsum dolor','Lorem ipsum','2015-04-14 17:50:02',' true'),(42,49,'Lorem ipsum','Lorem ipsum','2016-03-06 07:24:29',' true'),(37,17,'Lorem ipsum','Lorem ipsum dolor sit','2014-04-29 23:17:20',' true'),(42,32,'Lorem','Lorem ipsum dolor','2015-03-19 19:40:29',' true'),(40,9,'Lorem ipsum dolor','Lorem ipsum dolor sit','2014-04-25 02:29:33',' true'),(34,19,'Lorem','Lorem ipsum','2015-11-27 13:56:52',' true');
INSERT INTO Message (sender_id,receiver_id,topic,content,creation_date,read) VALUES (50,19,'Lorem ipsum dolor','Lorem','2014-06-14 11:01:24','false '),(37,35,'Lorem ipsum dolor','Lorem ipsum dolor sit amet,','2014-04-22 09:13:53','false '),(37,38,'Lorem','Lorem','2014-07-06 10:42:34','false '),(42,41,'Lorem ipsum dolor','Lorem','2014-04-19 01:39:40','false '),(40,36,'Lorem ipsum','Lorem ipsum dolor sit','2015-07-31 23:29:08','false '),(9,24,'Lorem ipsum dolor','Lorem ipsum dolor','2014-08-31 03:00:19','false '),(24,47,'Lorem ipsum','Lorem ipsum dolor sit amet,','2015-10-28 17:20:36','false '),(39,13,'Lorem ipsum dolor','Lorem ipsum dolor','2015-10-21 07:28:39','false '),(6,47,'Lorem','Lorem','2015-09-01 10:19:27','false '),(47,44,'Lorem ipsum dolor','Lorem ipsum','2016-03-30 14:17:12','false ');
INSERT INTO Message (sender_id,receiver_id,topic,content,creation_date,read) VALUES (50,7,'Lorem ipsum dolor','Lorem ipsum dolor sit','2015-05-07 16:10:29',' true'),(33,17,'Lorem ipsum','Lorem ipsum','2016-03-30 17:24:06',' true'),(49,24,'Lorem ipsum','Lorem','2014-10-15 18:39:29',' true'),(8,43,'Lorem','Lorem ipsum dolor sit','2015-04-09 13:15:22',' true'),(24,17,'Lorem','Lorem ipsum','2014-09-08 20:46:45',' true'),(29,15,'Lorem ipsum dolor','Lorem ipsum dolor sit amet,','2015-10-03 01:12:17',' true'),(14,9,'Lorem ipsum dolor','Lorem ipsum dolor sit','2014-05-27 16:14:40',' true'),(44,30,'Lorem ipsum dolor','Lorem ipsum','2014-11-24 20:59:32',' true'),(37,19,'Lorem','Lorem','2015-01-25 14:20:25',' true'),(34,14,'Lorem ipsum dolor','Lorem','2016-03-30 17:57:16',' true');
INSERT INTO Message (sender_id,receiver_id,topic,content,creation_date,read) VALUES (14,20,'Lorem ipsum dolor','Lorem ipsum','2014-07-24 02:51:43','false '),(19,18,'Lorem','Lorem','2016-01-14 22:32:29','false '),(31,23,'Lorem ipsum','Lorem ipsum dolor','2015-04-24 06:17:16','false '),(43,23,'Lorem ipsum','Lorem ipsum','2015-03-06 23:04:44','false '),(36,41,'Lorem ipsum','Lorem ipsum dolor sit amet,','2015-03-08 00:52:07','false '),(32,50,'Lorem','Lorem ipsum dolor sit','2014-06-01 11:56:53','false '),(27,45,'Lorem ipsum dolor','Lorem ipsum dolor sit amet,','2014-07-17 00:34:09','false '),(14,16,'Lorem','Lorem','2015-12-17 21:03:24','false '),(27,38,'Lorem ipsum dolor','Lorem ipsum dolor','2014-05-23 08:33:49','false '),(50,6,'Lorem ipsum dolor','Lorem ipsum','2014-11-24 07:00:55','false ');

INSERT INTO Administrator (user_id) VALUES (1),(2),(3),(4),(5);

INSERT INTO Feedback (source_user_id,target_user_id,evaluation,comment) VALUES (11,17,6,'Lorem ipsum dolor sit'),(33,29,4,'Lorem ipsum dolor'),(43,19,3,'Lorem ipsum dolor sit amet,'),(41,17,1,'Lorem ipsum dolor sit'),(36,35,5,'Lorem ipsum dolor sit amet, consectetuer adipiscing'),(21,19,8,'Lorem ipsum dolor sit amet,'),(42,49,1,'Lorem ipsum dolor sit amet,'),(8,13,1,'Lorem ipsum dolor sit amet,'),(39,49,1,'Lorem'),(32,37,9,'Lorem ipsum');
INSERT INTO Feedback (source_user_id,target_user_id,evaluation,comment) VALUES (34,8,3,'Lorem'),(6,47,10,'Lorem ipsum dolor sit amet, consectetuer adipiscing'),(25,22,1,'Lorem'),(23,7,8,'Lorem ipsum dolor sit amet, consectetuer adipiscing'),(9,13,2,'Lorem'),(38,32,3,'Lorem ipsum dolor sit amet,'),(10,15,7,'Lorem ipsum dolor sit amet, consectetuer adipiscing'),(44,14,10,'Lorem'),(29,12,8,'Lorem ipsum'),(50,19,9,'Lorem ipsum dolor sit amet, consectetuer');
INSERT INTO Feedback (source_user_id,target_user_id,evaluation,comment) VALUES (23,41,9,'Lorem ipsum dolor sit amet, consectetuer adipiscing'),(19,39,1,'Lorem ipsum dolor sit amet, consectetuer'),(15,29,3,'Lorem ipsum dolor sit'),(37,46,3,'Lorem'),(50,23,10,'Lorem ipsum dolor'),(25,22,8,'Lorem ipsum dolor sit'),(7,15,2,'Lorem ipsum dolor sit amet, consectetuer adipiscing'),(23,32,7,'Lorem'),(41,33,3,'Lorem ipsum dolor sit amet, consectetuer'),(22,10,3,'Lorem ipsum dolor');
INSERT INTO Feedback (source_user_id,target_user_id,evaluation,comment) VALUES (45,48,4,'Lorem ipsum'),(48,41,4,'Lorem ipsum dolor sit'),(25,47,5,'Lorem ipsum'),(9,19,5,'Lorem ipsum dolor sit'),(18,17,10,'Lorem'),(22,10,7,'Lorem ipsum dolor'),(43,18,10,'Lorem ipsum dolor sit amet, consectetuer adipiscing'),(29,23,8,'Lorem ipsum dolor sit amet, consectetuer'),(25,43,8,'Lorem ipsum dolor sit amet, consectetuer adipiscing'),(40,9,4,'Lorem');
INSERT INTO Feedback (source_user_id,target_user_id,evaluation,comment) VALUES (45,46,5,'Lorem ipsum dolor sit'),(33,13,8,'Lorem ipsum dolor'),(15,24,2,'Lorem ipsum dolor sit amet, consectetuer'),(38,37,5,'Lorem ipsum dolor sit'),(27,31,3,'Lorem ipsum dolor sit amet, consectetuer'),(18,12,2,'Lorem ipsum dolor sit amet,'),(13,25,10,'Lorem ipsum dolor'),(49,24,8,'Lorem ipsum dolor sit amet, consectetuer'),(8,19,10,'Lorem ipsum dolor sit amet, consectetuer adipiscing'),(30,21,9,'Lorem ipsum dolor');

INSERT INTO AdminAction (admin_id,motive,creation_date) VALUES (1,'Lorem ipsum','2014-08-23 03:58:36'),(4,'Lorem ipsum dolor sit','2015-05-27 12:11:49'),(4,'Lorem ipsum dolor','2015-04-25 07:15:14'),(2,'Lorem ipsum dolor','2015-12-24 13:37:06'),(5,'Lorem','2014-06-05 04:09:50'),(2,'Lorem ipsum dolor sit amet,','2015-05-27 11:01:16'),(4,'Lorem ipsum dolor sit','2014-08-10 03:22:51'),(4,'Lorem ipsum dolor sit','2015-02-17 18:49:11'),(5,'Lorem ipsum dolor','2016-03-14 00:57:48'),(3,'Lorem ipsum','2014-07-10 06:20:56');

INSERT INTO BlockUser(admin_action_id,user_id) VALUES (1,47),(2,48),(3,9),(4,50);

INSERT INTO RemoveComment(admin_action_id,comment_id) VALUES (5,10),(6,20),(7,30);

INSERT INTO BlockAuction(admin_action_id,auction_id) VALUES (8,47),(9,48),(10,9);