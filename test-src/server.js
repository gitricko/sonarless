"use strict";

const express =  require('express');
const RL = require('./reinforcejs');
const fs = require('fs');
const url = require('url');
const util = require('util');
const MongoDB = require('mongodb');
const MongoClient = MongoDB.MongoClient;
const ObjectId = MongoDB.ObjectId;

const app = express();
var port = process.env.PORT;
if(typeof(port) === 'undefined') {
	port = 3000;
}
const hostname = '0.0.0.0';

const ERR_AGENT_NOT_INIT = "Agent %s has not been initialized";

var bodyParser = require('body-parser');
app.use(bodyParser.json());       // to support JSON-encoded bodies
app.use(bodyParser.urlencoded({     // to support URL-encoded bodies
  extended: true
}));

var brains = [];
var brainCount = 0;

app.get('/agents/', (request, res) => {
  res.setHeader("Content-Type", "application/json");
  res.send(JSON.stringify({"Total Agents": brainCount}));
});

// return num. no wrapping in JSON yet
app.post('/agents/', (request, res) => {
  var agent = JSON.parse(request.body.agent);
  var spec = JSON.parse(request.body.spec);
  var numStates = parseInt(request.body.numStates);
  var numActions = parseInt(request.body.numActions);
  brains.push(initializeBrain(agent, spec, numStates, numActions));
  res.status(200).send(brainCount.toString());
  brainCount += 1;
});

// return direct actions num. no wrapping in JSON yet
app.post('/agents/:id/act/', (request, res) => {
  var brain = brains[parseInt(request.params.id)];
  var ret_action = null;

  if (brain != null){
    var cur_state_array = JSON.parse(request.body.state);
    ret_action = brain.act(cur_state_array);
    res.status(200);
  }else{
    ret_action = util.format(ERR_AGENT_NOT_INIT,parseInt(request.params.id));
    console.log("error: /act: " + ret_action);
    res.status(404);
  }
  res.send(ret_action.toString());
});

// return OK if no error. Client not using this return input. no wrapping in JSON yet
app.post('/agents/:id/learn/', (request, res) => {
  var brain = brains[parseInt(request.params.id)];
  var ret_msg = null;

  if (brain != null){
    var reward = parseFloat(request.body.reward);
    brain.learn(reward);
    ret_msg = 'OK';
    res.status(200);
  }else{
    ret_msg = util.format(ERR_AGENT_NOT_INIT,parseInt(request.params.id));
    console.log("error: /learn: " + ret_msg);
    res.status(404);
  }
  res.send(ret_msg.toString());
});

app.put('/agents/:id/spec/', (request, res) => {

  var updateAlphaEpsilon = function(spec){
    // syntactic sugar function for getting default parameter values
    var getopt = function(opt, field_name, default_value) {
      if(typeof opt === 'undefined') { return default_value; }
      return (typeof opt[field_name] !== 'undefined') ? opt[field_name] : default_value;
    }
    this.epsilon = getopt(spec, 'epsilon', this.epsilon); // for epsilon-greedy policy
    this.alpha = getopt(spec, 'alpha', this.alpha); // value function learning rate
  };

  var brain = brains[parseInt(request.params.id)];
  var ret_msg = null;

  if (brain != null){
    var spec = JSON.parse(request.body.spec);
    updateAlphaEpsilon = updateAlphaEpsilon.bind(brain);
    updateAlphaEpsilon(spec);
    ret_msg = 'OK';
    res.status(200);
  }else{
    ret_msg = util.format(ERR_AGENT_NOT_INIT,parseInt(request.params.id));
    console.log("error: /spec: " + ret_msg);
    res.status(404);
  }
  res.send(ret_msg.toString());
});

app.get('/agents/:id/spec/', (request, res) => {
  var brain = brains[parseInt(request.params.id)];
  generateGetResponse(getSpec, res, brain);
});

app.get('/agents/:id/model/', (request, res) => {
  var brain = brains[parseInt(request.params.id)];
  generateGetResponse(brain.toJSON, res, brain);
});

app.put('/agents/:id/model/', (request, res) => {
  var obj = JSON.parse(request.body.model);
  var brain = brains[parseInt(request.params.id)];
  brain.fromJSON(obj);
  if (request.body.epsilon != undefined){
    brain.epsilon = parseFloat(request.body.epsilon);
  }
  if (request.body.alpha != undefined){
    brain.alpha = parseFloat(request.body.alpha);
  }
  res.status(200).send();
});

app.post('/agents/:id/model/db_save/', (request, res) => {
  var brain = brains[parseInt(request.params.id)];
  var successRate = request.body.success;
  executeQuery(persistModel.bind(this, brain, successRate));
  res.status(200).send();
});

app.post('/agents/:id/loadPretrainedBrain/', (request, res) => {
  var agent = JSON.parse(request.body.agent);
  var spec = JSON.parse(request.body.spec);
  var obj = JSON.parse(fs.readFileSync('./reinforcejs/agentzoo/wateragent.json', 'utf8'));
  var numActions = agent.actions.length;
  var numStates = agent.num_states;
  brains[parseInt(request.params.id)] = initializeBrain(agent, spec, numStates, numActions);
  brains[parseInt(request.params.id)].fromJSON(obj);
  res.status(200).send();
});

app.get('/db_models/', (request, res) => {
  var callback = function(docs) {
    res.status(200).send(docs);
  };
  executeQuery(listModels.bind(this, callback));
});

app.post('/db_models/:id', (request, res) => {
  var agent = JSON.parse(request.body.agent);
  var spec = JSON.parse(request.body.spec);
  var brainID = JSON.parse(request.body.id);
  var numActions = agent.actions.length;
  var numStates = agent.num_states;
  var callback = function(doc) {
    var model = doc.model;
    brains[brainID] = initializeBrain(agent, spec, numStates, numActions);
    brains[brainID].fromJSON(model);
    res.status(200).send();
  };
  executeQuery(findModel.bind(this, request.params.id, callback));
});

app.delete('/db_models/:id', (request, res) => {
  var callback = function() {
    res.status(200).send();
  };
  executeQuery(deleteModel.bind(this, request.params.id, callback));
});

app.use(express.static('reinforcejs'));

app.listen(port, hostname, () => {
  console.log(`Server running at http://${hostname}:${port}/`);
});

function deleteModel(brainID, callback, collection) {
  collection.deleteOne({_id: ObjectId(brainID)}, function(err, doc) {
        callback(doc);
      });
}

function findModel(brainID, callback, collection) {
  collection.findOne({_id: ObjectId(brainID)}, function(err, doc) {
        callback(doc);
      });
}

function listModels(callback, collection) {
  collection.find({}).project({
      timestamp: 1,
      success: 1,
      epsilon: 1,
      alpha: 1
    })
      .toArray(function(err, docs) {
        callback(docs);
      });
}

function persistModel(brain, successRate, collection) {
  collection.insertOne({
      timestamp: new Date().toLocaleString(),
      alpha: brain.alpha,
      epsilon: brain.epsilon,
      success: successRate,
      model: brain.toJSON()
    });
}

function executeQuery(callback) {
  var connection = getMongoConnection();
  MongoClient.connect(connection.url, function(err, db) {
    db = db.db(connection.schema);
    if(err) {
      console.log('MongoDB connection to ' + connection.url + ' failed!');
      throw err;
    }
    var collection = db.collection(connection.collection, function(err, coll) {
      if(err) {
        console.log('MongoDB connection to database ' + connection.collection + ' failed!');
        throw err;
      }
      typeof(callback) === 'function' && callback(coll);
    });
  });
}

function getMongoConnection() {
  var hostname = process.env.MONGODB_HOST || '127.0.0.1'
  var port = process.env.MONGODB_PORT || 27772
  var schema = process.env.MONGO_SCHEMA || 'rljs_db'
  var user = process.env.MONGODB_USR 
  var password = process.env.MONGODB_PWD

  if(typeof(user) !== 'undefined' && typeof(password) !== 'undefined') {
    var uri = `mongodb://${user}:${password}@${hostname}:${port}/`;
  } else {
    var uri = `mongodb://${hostname}:${port}/`;
  }
 
  var collection = 'models';

  return {
    url: uri,
    schema: schema,
    collection: collection
  };
}

function initializeBrain(agent, spec, numStates, numActions) {
  agent.getNumStates = function() { return numStates; };
  agent.getMaxNumActions = function() { return numActions; };
  //console.log(typeof(numStates) + " " + typeof(numStates) + " "  + typeof(agent));
  return new RL.DQNAgent(agent, spec);
}

// function variable to enhance DQNAgent in rl.js
var getSpec = function(){
  var specDict = {};
  specDict.gamma = this.gamma;
  specDict.epsilon = this.epsilon;
  specDict.alpha = this.alpha;
  specDict.experience_add_every = this.experience_add_every;
  specDict.experience_size = this.experience_size;
  specDict.learning_steps_per_iteration = this.learning_steps_per_iteration;
  specDict.tderror_clamp = this.tderror_clamp;
  specDict.num_hidden_units = this.num_hidden_units;
  return specDict;
};

function generateGetResponse(func, res, brain) {
  var ret_msg = '';
  if (typeof(brain) !== 'undefined'){
    func = func.bind(brain);
    ret_msg = func();
    res.status(200);
  }else{
    ret_msg = 'Brain not initialized';
    res.status(404);
  }

  if (typeof(ret_msg) === 'undefined'){
    ret_msg = '';
  }
  res.setHeader("Content-Type", "application/json");
  res.send(JSON.stringify(ret_msg));
}
