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