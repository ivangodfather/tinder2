//
//  MessagesViewController.m
//  Tinder
//
//  Created by Ivan Ruiz Monjo on 26/08/14.
//  Copyright (c) 2014 ivan. All rights reserved.
//

#import "MessagesViewController.h"
#import "UserParse.h"
#import "MessageParse.h"
#import "UserTableViewCell.h"
#import "UserMessagesViewController.h"

#define SECONDS_DAY 24*60*60

@interface MessagesViewController () <UITableViewDataSource, UITableViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UITextField *searchTextField;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *sidebarButton;

@property NSMutableArray *usersParseArray;
@property NSArray *filteredUsersArray;
@property (weak, nonatomic) IBOutlet UIButton *cameraButton;
@property NSMutableArray *messages;
@end

@implementation MessagesViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _sidebarButton.target = self.revealViewController;
    _sidebarButton.action = @selector(revealToggle:);

    [self.view addGestureRecognizer:self.revealViewController.panGestureRecognizer];
    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 48, 20)];
    self.searchTextField.leftView = paddingView;
    self.searchTextField.leftViewMode = UITextFieldViewModeAlways;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedNotification:) name:receivedMessage object:nil];


    [self customize];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)customize
{
    self.tableView.backgroundColor = WHITE_COLOR;
    self.tableView.separatorColor = GRAY_COLOR;
    self.searchTextField.backgroundColor = WHITE_COLOR;
    self.searchTextField.backgroundColor = GRAY_COLOR;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:YES];
    [self loadChatPersons];
}

- (void)receivedNotification:(NSNotification *)notification
{
    [self.usersParseArray removeAllObjects];
    [self.messages removeAllObjects];
    [self loadChatPersons];
}

- (void)loadChatPersons
{
    self.usersParseArray = [NSMutableArray new];
    self.messages = [NSMutableArray new];
    self.filteredUsersArray = [NSArray new];

    PFQuery *messageQueryFrom = [MessageParse query];
    [messageQueryFrom whereKey:@"fromUserParse" equalTo:[UserParse currentUser]];
    PFQuery *messageQueryTo = [MessageParse query];
    [messageQueryTo whereKey:@"toUserParse" equalTo:[UserParse currentUser]];
    PFQuery *both = [PFQuery orQueryWithSubqueries:@[messageQueryFrom, messageQueryTo]];
    [both orderByDescending:@"createdAt"];

    [both findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        NSMutableSet *users = [NSMutableSet new];
        for (MessageParse *message in objects) {
            if(![message.fromUserParse.objectId isEqualToString:[UserParse currentUser].objectId]) {
                NSUInteger count = users.count;
                [users addObject:message.fromUserParse];
                if (users.count > count) {
                    [message.fromUserParse fetchIfNeededInBackgroundWithBlock:^(PFObject *object, NSError *error) {
                        [self.messages addObject:message];
                        [self.usersParseArray addObject:message.fromUserParse];
                        NSInteger position = [self.usersParseArray indexOfObject:message.fromUserParse];
                        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:position inSection:0];
                        [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                    }];
                }
            }
            if(![message.toUserParse.objectId isEqualToString:[UserParse currentUser].objectId]) {
                NSUInteger count = users.count;
                [users addObject:message.toUserParse];
                if (users.count > count) {
                    [message.toUserParse fetchIfNeededInBackgroundWithBlock:^(PFObject *object, NSError *error) {
                        [self.messages addObject:message];
                        [self.usersParseArray addObject:message.toUserParse];

                        NSInteger position = [self.usersParseArray indexOfObject:message.toUserParse];
                        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:position inSection:0];
                        [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                    }];
                }
            }
        }
        [self.tableView reloadData];
    }];
}

#pragma mark TableView Delegate

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UserTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UserParse *user;
    if (self.filteredUsersArray.count) {
        user = [self.filteredUsersArray objectAtIndex:indexPath.row];
    } else {
        user = [self.usersParseArray objectAtIndex:indexPath.row];
    }

    cell.nameTextLabel.text = user.username;
    cell.nameTextLabel.textColor = BLACK_COLOR;
    cell.userImageView.layer.cornerRadius = cell.userImageView.frame.size.width / 2;
    cell.userImageView.clipsToBounds = YES;
    cell.userImageView.layer.borderWidth = 2.0,
    cell.userImageView.layer.borderColor = BLUE_COLOR.CGColor;

    UIImageView *accesory = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"accesory"]];
    accesory.frame = CGRectMake(15, 0, 15, 15);
    accesory.contentMode = UIViewContentModeScaleAspectFit;
    cell.accessoryView = accesory;

    MessageParse *message = [self.messages objectAtIndex:indexPath.row];
    cell.lastMessageLabel.text = message.text;
    if (!message.read && [message.toUserParse.objectId isEqualToString:[UserParse currentUser].objectId]) {
        cell.lastMessageLabel.textColor = ORANGE_COLOR;
    } else {
        cell.lastMessageLabel.textColor = GRAY_COLOR;
    }
    cell.dateLabel.textColor = BLACK_COLOR;
    NSDateFormatter *dateFormatter = [NSDateFormatter new];
    [dateFormatter setDoesRelativeDateFormatting:YES];
    if ([[message createdAt] timeIntervalSinceNow] * -1 < SECONDS_DAY) {
        dateFormatter.timeStyle = NSDateFormatterShortStyle;
    } else {
        dateFormatter.dateStyle = NSDateFormatterShortStyle;
    }
    cell.dateLabel.text = [dateFormatter stringFromDate:[message createdAt]];
    UIView *bgColorView = [[UIView alloc] init];
    bgColorView.backgroundColor = RED_COLOR;
    [cell setSelectedBackgroundView:bgColorView];
    [user.photo getDataInBackgroundWithBlock:^(NSData *data, NSError *error) {
        cell.userImageView.image = [UIImage imageWithData:data];
    }];

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.searchTextField.text.length) {
        return self.filteredUsersArray.count;
    }
    return self.usersParseArray.count;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"chat"]) {
        UserMessagesViewController *vc = segue.destinationViewController;
        if (self.filteredUsersArray.count) {
            vc.toUserParse = [self.filteredUsersArray objectAtIndex:self.tableView.indexPathForSelectedRow.row];
        } else {
            vc.toUserParse = [self.usersParseArray objectAtIndex:self.tableView.indexPathForSelectedRow.row];
        }
    }
}

- (IBAction)searchTextFieldChanged:(UITextField *)textfield
{
    NSLog(@"frame %@", NSStringFromCGRect(self.cameraButton.frame));
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"username CONTAINS %@",textfield.text];
    self.filteredUsersArray = [self.usersParseArray filteredArrayUsingPredicate:predicate];
    [self.tableView reloadData];
}

- (IBAction)searchTextFieldEnd:(id)sender {
    [sender resignFirstResponder];
}

- (IBAction)sendPhoto:(id)sender
{
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:^{

    }];
}

#pragma mark KeyBoard Notifications

- (void)keyboardDidShow:(NSNotification *)notification
{
    [UIView animateWithDuration:1.5
                          delay:0
         usingSpringWithDamping:0.5
          initialSpringVelocity:0.2
                        options:UIViewAnimationOptionCurveEaseIn animations:^{
                            CGRect rect = self.cameraButton.frame;
                            rect.origin.y -= 200;
                            self.cameraButton.frame = rect;
                        } completion:^(BOOL finished) {

                        }];
}

- (void)keyboardDidHide:(NSNotification *)notification
{
    [UIView animateWithDuration:1.5
                          delay:0
         usingSpringWithDamping:0.5
          initialSpringVelocity:0.2
                        options:UIViewAnimationOptionCurveEaseIn animations:^{
                            CGRect rect = self.cameraButton.frame;
                            rect.origin.y += 200;
                            self.cameraButton.frame = rect;
                        } completion:^(BOOL finished) {
                            
                        }];
}

#pragma mark - PickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self dismissViewControllerAnimated:YES completion:nil];
    UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
    PFFile *file = [PFFile fileWithData:UIImageJPEGRepresentation(image, 0.9)];

    [file saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        __block int count = 0;
        for (UserParse *user in self.usersParseArray) {
            MessageParse *message = [MessageParse object];
            message.fromUserParse = [UserParse currentUser];
            message.toUserParse = user;
            message.read = NO;
            message.image = file;
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:count inSection:0];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            [message saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                count++;
                PFQuery *query = [PFInstallation query];
                [query whereKey:@"objectId" equalTo:user.installation.objectId];
                [PFPush sendPushMessageToQueryInBackground:query
                                               withMessage:@"new image!"];
                if (count == self.usersParseArray.count) {
                    [self.tableView reloadData];
                }

            }];


        }

    }];






}
@end
