<?php
$client = new MongoDB\Driver\Manager(
    'mongodb://localhost:27017'
);
if($_SERVER['REQUEST_METHOD']=="GET") {
	//get request
	if($_GET['request']=="thumbnail") {
		$query = new MongoDB\Driver\Query(array('_id' => new MongoDB\BSON\ObjectId($_GET['oid'])),[]);
		$cursor = $client->executeQuery('media_organizer.files',$query);
		$cursor->setTypeMap(['document' => 'stdClass']);
		$cursor->rewind();
		if($cursor->valid()) {
			$current = $cursor->current();
		    $thumbnail_path = $current->thumb_path;
		    header("Content-Type: image/jpeg");
		    header("Content-Length: ".filesize($thumbnail_path));
		    $fp = fopen($thumbnail_path, 'rb');
		    fpassthru($fp);
		    fclose($fp);
		} else {
		}
		exit;
	} else if($_GET['request']=="preview") {
		sleep(2);
		$query = new MongoDB\Driver\Query(array('_id' => new MongoDB\BSON\ObjectId($_GET['oid'])),[]);
		$cursor = $client->executeQuery('media_organizer.files',$query);
		$cursor->setTypeMap(['document' => 'stdClass']);
		$cursor->rewind();
		if($cursor->valid()) {
			$current = $cursor->current();
		    $preview_path = $current->prev_path;
		    header("Content-Type: image/jpeg");
		    header("Content-Length: ".filesize($preview_path));
		    $fp = fopen($preview_path, 'rb');
		    fpassthru($fp);
		    fclose($fp);
		} else {
		}
		exit;
	} else if($_GET['request']=="download") {
		
	}
}
?>