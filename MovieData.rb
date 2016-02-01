class MovieData
  @movieList = []
  @userList = []
  @dataFile = ""
  @testFile = ""
  @testList = []

#user_id movie_id rating timestamp

  def initialize(dataFolder, testFile = nil);
    @movieList = []
    @userList = []
    if testFile.nil?
      @dataFile = open File.expand_path("../#{dataFolder}/u.data", __FILE__)
    else
      @dataFile = open File.expand_path("../#{dataFolder}/#{testFile}.base", __FILE__)
      @testFile = open File.expand_path("../#{dataFolder}/#{testFile}.test", __FILE__)
    end
    curLine = @dataFile.gets.chomp
    while curLine != nil  #go through and parse each line of the data
      curLine = curLine.chomp
      curLine = curLine.split(/\t/)
      newUser = User.new(curLine[0].to_i)
      if @userList.include? newUser
        @userList[@userList.index(newUser)].addReview(curLine[1].to_i, curLine[2].to_i, curLine[3].to_i)
      else
        newUser.addReview(curLine[1].to_i, curLine[2].to_i, curLine[3].to_i)
        @userList.push newUser
      end
      @movieList.push curLine[1].to_i
      curLine = @dataFile.gets
    end
    @userList.uniq
    @movieList.uniq

  end

  def rating (u, m)
    if !@userList.include? User.new(u)
      raise "Tried to find rating from user that does not exist"
    end
    return @userList[@userList.index User.new(u)].checkRating m
  end

  def predict (u, m)
    prediction = 0
    additions = 0
    #puts "in predict user_id index is #{@userList.index User.new u}"
    similarUsers = most_similar(u)
    similarUsers.each do |entry|
      user = @userList[@userList.index User.new entry[0]]
      if user.hasSeen m
        score = user.checkRating m
        entry[1].times do
          prediction += score
          additions += 1
        end
      end
    end
    prediction.to_f
    additions.to_f
    prediction = prediction / additions
    prediction = (prediction*10).to_i / 10.to_f
    return prediction

  end

  def movies (u)
    if !@userList.include? User.new(u)
      raise "Tried to find movies from user that does not exist"
    end
    return @userList[@userList.index User.new(u)].getReviewedMovies
  end

  def viewers (m)
    if !@movieList.include? m
      raise "Tried to viewers of a movie that does not exist"
    end
    watchers = []
    @userList.each do |user|
      if user.hasSeen m
        watchers.push user.user_id
      end
    end
    return watchers
  end

  def run_test (k)
    fetchTestData(k)
    @testList.each do |aTest|
      #puts "the rating that user #{aTest[:user_id]} gave to movie #{aTest[:movie_id]} actually was #{rating(aTest[:user_id], aTest[:movie_id])}"
      #puts "in run_test user_id index is #{@userList.index User.new aTest[:user_id]}"
      aTest[:predicted_rating] = predict(aTest[:user_id], aTest[:movie_id])
    end
    return MovieTest.new (@testList)
  end

  def fetchTestData (k)
    @testList = []
    if k.nil?
      curLine = @testFile.gets.chomp
      while curLine != nil  #go through and parse each line of the data
        curLine = curLine.chomp
        curLine = curLine.split(/\t/)
        review = {user_id: curLine[0].to_i, movie_id: curLine[1].to_i, actual_rating: curLine[2].to_i, predicted_rating: nil}
        @testList.push(review)
        curLine = @testFile.gets
      end
    else
      curLine = @testFile.gets.chomp
      (1..k).each do  #go through and parse each line of the data
        curLine = curLine.chomp
        curLine = curLine.split(/\t/)
        review = {user_id: curLine[0].to_i, movie_id: curLine[1].to_i, actual_rating: curLine[2].to_i, predicted_rating: nil}
        @testList.push(review)
        curLine = @testFile.gets
      end
    end
    @testFile.rewind
  end

  def similarity(user_id1, user_id2)
    similarity = 0
  #  puts "user 1 is: #{user_id1}, user 2 is: #{user_id2}"
  #  puts "Index of user in userlist is: #{@userList.index(User.new (user_id1))}"
    @userList[@userList.index(User.new user_id1)].reviews.each do |review|  #Find if users have reviewed the same movie, and if htey gave it the same score
      @userList[@userList.index(User.new user_id2)].reviews.each do |checkAgainst|
        if review[0] == checkAgainst[0] && review[1] == checkAgainst[1]
          similarity += 1  #if they did, increment their similiarity
        end
      end
    end
    return similarity
  end

  def most_similar(u)
    clonedList = @userList.dup
    clonedList.delete(User.new(u))  #don't compare user in question to itself
    userRanking = []
  #  puts "in most_similar user_id index is #{@userList.index User.new u}"
    clonedList.each do |user|
      userRanking.push([user.user_id, similarity(u, user.user_id)])  #check the similarity of each user
    end
    userRanking = userRanking.sort_by {|x,y|y}.reverse  #sort results and return
    return userRanking
  end

end

class User
  attr_reader :user_id
  attr_reader :reviews
  def initialize (user_id)
    @user_id = user_id
    @reviews = []
  end
  def addReview (movie_id, rating, timestamp)
    @reviews.push [movie_id, rating, timestamp]
  end
  def ==(another_User)
    self.user_id == another_User.user_id
  end
  def checkRating (movie_id)
    @reviews.each do |review|
      if review[0] == movie_id
        return review[1]
      end
    end
    return 0
  end
  def getReviewedMovies
    toReturn = []
    @reviews.each do |review|
      toReturn.push review[0]
    end
    return toReturn
  end
  def hasSeen m
    @reviews.each do |review|
      if review[0] == m
        return true
      end
    end
    return false
  end
end


class MovieTest
  attr_reader :dataSet
  def initialize (dataSet)
    @dataSet = dataSet
  end

  def mean
    error = 0
    @dataSet.each do |data|
      error += (data[:predicted_rating] - data[:actual_rating])
    end
    return error = error/@dataSet.size
  end

  def stddev
    standardDiv = 0
    curMean = self.mean
    @dataSet.each do |data|
      standardDiv += ((data[:predicted_rating] - data[:actual_rating]) - curMean)**2
    end
    return Math.sqrt(standardDiv/@dataSet.size)
  end

  def rms
    rootMeanSquare = 0
    @dataSet.each do |data|
      rootMeanSquare += (data[:predicted_rating] - data[:actual_rating])**2
    end
    return Math.sqrt(rootMeanSquare/@dataSet.size)
  end

  def to_a
    return @dataSet
  end

end

newThing = MovieData.new "ml-100k", :u1
#puts newThing.movies(1).inspect
#puts newThing.viewers(1).inspect
storage = newThing.run_test 10
puts storage.dataSet.inspect
puts storage.mean
puts storage.stddev
puts storage.to_a
puts storage.rms
