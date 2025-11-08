package client

import (
	"context"
	pb "post-service/pkg/generated/social_graph"

	"google.golang.org/grpc"
)
type SocialGraphClient struct {
    client pb.SocialGraphServiceClient
    conn *grpc.ClientConn
}

func NewSocialGraphClient(address string)(*SocialGraphClient, error){
    conn, err := grpc.Dial(address, grpc.WithInsecure())
    if err != nil {
        return nil, err
    }
    return &SocialGraphClient{
        client: pb.NewSocialGraphServiceClient(conn),
        conn: conn,
    }, nil
}

func (c *SocialGraphClient) GetFollowers(ctx context.Context, userID int64, limit, offset int32)(*pb.GetFollowersResponse, error){
    return c.client.GetFollowers(ctx, &pb.GetFollowersRequest{
        UserId: userID,
        Limit: limit,
        Offset: offset,
    })
}

func (c *SocialGraphClient) Close() {
    c.conn.Close()
}


