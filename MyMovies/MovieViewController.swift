//
//  MovieViewController.swift
//  MyMovies
//
//  Created by Quoc Huy on 10/10/16.
//  Copyright © 2016 HuyPhung. All rights reserved.
//

import UIKit
import AFNetworking
import MBProgressHUD
import ReachabilitySwift

class MovieViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var networkErrorView: UIView!

    
    var movies = [NSDictionary]()
    let baseUrl = "https://image.tmdb.org/t/p/w342"
    var endpoint: String!
    
    let reachability = Reachability()!
    
    // Initialize a UIRefreshControl
    let refreshControl = UIRefreshControl()
    
    var loadCheckPoint = true
    var refreshControlFirstTime = false
    
    let searchBar = UISearchBar()
    var filteredArray = [NSDictionary]()
    var shouldShowSearchResults = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        tableView.dataSource = self
        tableView.delegate = self
        
        createSearchBar()
        
        if reachability.isReachable {
            if reachability.isReachableViaWiFi {
                print("Reachable via WiFi")
                loadMovie()
                loadCheckPoint = true
                networkErrorView.isHidden = true
            } else {
                print("Reachable via Cellular")
                loadMovie()
                loadCheckPoint = true
                networkErrorView.isHidden = true
            }
        } else {
            print("Network not reachable")
            loadCheckPoint = false
            networkErrorView.isHidden = false
        }
        

        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        NotificationCenter.default.addObserver(self, selector:  #selector(MovieViewController.reachabilityChanged),name: ReachabilityChangedNotification,object: reachability)
        do{
            try reachability.startNotifier()
        }catch{
            print("could not start reachability notifier")
        }
        
        refreshControl.addTarget(self, action: #selector(MovieViewController.loadMovie), for: UIControlEvents.valueChanged)
        // Add refresh control to table view
        tableView.insertSubview(refreshControl, at: 0)
        refreshControlFirstTime = true
        
        if loadCheckPoint == false {
            refreshControl.endRefreshing()
            refreshControl.removeFromSuperview()
        }
        
    }

    // Function used to check Wifi and Cellular connection
    func reachabilityChanged(note: NSNotification) {
        
        let reachability = note.object as! Reachability
        
        if reachability.isReachable {
            if reachability.isReachableViaWiFi {
                print("Reachable via WiFi")
                if self.loadCheckPoint == false {
                    loadMovie()
                    loadCheckPoint = true
                }
                networkErrorView.isHidden = true
                refreshControl.addTarget(self, action: #selector(MovieViewController.loadMovie), for: UIControlEvents.valueChanged)
                // Add refresh control to table view
                tableView.insertSubview(refreshControl, at: 0)
            } else {
                print("Reachable via Cellular")
                if self.loadCheckPoint == false {
                    loadMovie()
                    loadCheckPoint = true
                }
                refreshControl.addTarget(self, action: #selector(MovieViewController.loadMovie), for: UIControlEvents.valueChanged)
                // Add refresh control to table view
                tableView.insertSubview(refreshControl, at: 0)
                networkErrorView.isHidden = true
            }
        } else {
            print("Network not reachable")
            loadCheckPoint = false
            networkErrorView.isHidden = false
            if refreshControlFirstTime == true {
                refreshControl.endRefreshing()
                refreshControl.removeFromSuperview()
                refreshControlFirstTime = false
            }
        }
    }
    

    // Function used to load the moive
    func loadMovie() {
        let apiKey = "a07e22bc18f5cb106bfe4cc1f83ad8ed"
        let url = URL(string: "https://api.themoviedb.org/3/movie/\(endpoint!)?api_key=\(apiKey)")
        let request = URLRequest(
            url: url!,
            cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalCacheData,
            timeoutInterval: 10)
        let session = URLSession(
            configuration: URLSessionConfiguration.default,
            delegate: nil,
            delegateQueue: OperationQueue.main
        )
        
        // Display HUD right before the request is made
        MBProgressHUD.showAdded(to: self.view, animated: true)
        
        let task: URLSessionDataTask =
            session.dataTask(with: request,
                             completionHandler: { (dataOrNil, response, error) in
                                if let data = dataOrNil {
                                    if let responseDictionary = try! JSONSerialization.jsonObject(
                                        with: data, options:[]) as? NSDictionary {
                                        //print("response: \(responseDictionary)")
                                        self.movies = responseDictionary["results"] as! [NSDictionary]
                                        //print(self.movies)
                                        self.tableView.reloadData()
                                        self.refreshControl.endRefreshing()
                                    }
                                }
                                // Hide HUD once the network request comes back (must be done on main UI thread)
                                MBProgressHUD.hide(for: self.view, animated: true)
                                
            })
        task.resume()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if shouldShowSearchResults {
            return filteredArray.count
        } else {
            return movies.count
        }
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //let cell = UITableViewCell()
        //cell.textLabel?.text = movies[indexPath.row]["title"] as? String
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "movieCell") as! MovieCell
        
        if shouldShowSearchResults {
            cell.titleLabel.text = filteredArray[indexPath.row]["title"] as? String
            cell.overviewLabel.text = filteredArray[indexPath.row]["overview"] as? String
            
            // Set the style of vote average value
            let myFormatter = NumberFormatter()
            myFormatter.decimalSeparator = "."
            myFormatter.minimumFractionDigits = 2
            myFormatter.minimumIntegerDigits  = 1
            
            let voteAverageDouble = filteredArray[indexPath.row]["vote_average"] as! Double
            let voteAverage = myFormatter.string(from: NSNumber(value: voteAverageDouble))
            let voteCount = String(describing: filteredArray[indexPath.row]["vote_count"]!)
            var reviewString = " (" + voteCount + " reviews)"
            if (voteCount == "0") {
                reviewString = " (No review)"
            }
            cell.ratingLabel.text = String(voteAverage!) + reviewString
            
            if let posterPath = filteredArray[indexPath.row]["poster_path"] as? String {
                let posterUrl = URL(string: baseUrl + posterPath)
                cell.posterView.setImageWith(posterUrl!)
            }
        } else {
            cell.titleLabel.text = movies[indexPath.row]["title"] as? String
            cell.overviewLabel.text = movies[indexPath.row]["overview"] as? String
            
            // Set the style of vote average value
            let myFormatter = NumberFormatter()
            myFormatter.decimalSeparator = "."
            myFormatter.minimumFractionDigits = 2
            myFormatter.minimumIntegerDigits  = 1
            
            let voteAverageDouble = movies[indexPath.row]["vote_average"] as! Double
            let voteAverage = myFormatter.string(from: NSNumber(value: voteAverageDouble))
            let voteCount = String(describing: movies[indexPath.row]["vote_count"]!)
            var reviewString = " (" + voteCount + " reviews)"
            if (voteCount == "0") {
                reviewString = " (No review)"
            }
            cell.ratingLabel.text = String(voteAverage!) + reviewString
            
            if let posterPath = movies[indexPath.row]["poster_path"] as? String {
                let posterUrl = URL(string: baseUrl + posterPath)
                cell.posterView.setImageWith(posterUrl!)
            }
        }
        
        return cell
        
    }
    
    // Function to create the search bar
    func createSearchBar () {
        
        searchBar.showsCancelButton = true
        searchBar.placeholder = "Search the movie here"
        searchBar.delegate = self
        
        self.navigationItem.titleView = searchBar
        
    }
    
    // Function for adding search
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        filteredArray = movies.filter({ (names) -> Bool in
            
            // Access the movie Title
            let tmpTitle = names["title"] as! String
            
            // Create the range for both
            let range = tmpTitle.range(of: searchText, options: NSString.CompareOptions.caseInsensitive)
            
            return range != nil
            
        })
        
        if searchText != "" {
            shouldShowSearchResults = true
            self.tableView.reloadData()
        } else {
            shouldShowSearchResults = false
            self.tableView.reloadData()
        }
        
    }
    
    // End function for adding search
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        searchBar.endEditing(true)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        shouldShowSearchResults = true
        searchBar.endEditing(true)
        self.tableView.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
        shouldShowSearchResults = false
        self.tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
        
        let nextVC = segue.destination as! DetailViewController
        
        let ip = tableView.indexPathForSelectedRow
        
        if shouldShowSearchResults {
            nextVC.movie = self.filteredArray[(ip?.row)!]
        } else {
            nextVC.movie = self.movies[(ip?.row)!]
        }
    }
    
    // Deinit stop notifier
    deinit {
        reachability.stopNotifier()
        NotificationCenter.default.removeObserver(self,
                                                  name: ReachabilityChangedNotification,
                                                object: reachability)
    }

}
